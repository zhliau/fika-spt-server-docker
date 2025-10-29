#!/bin/bash -e

build_dir=/opt/build
mounted_dir=/opt/server
spt_binary=SPT.Server.Linux
uid=${UID:-1000}
gid=${GID:-1000}

backup_dir_name=${BACKUP_DIR:-backups}
backup_dir=$mounted_dir/$backup_dir_name

spt_current_major_version=4
spt_version=${SPT_VERSION:-4.0.1-40087-1eacf0f}
spt_version=$(echo $spt_version | cut -d '-' -f 1)
spt_backup_dir=$backup_dir/spt/$(date +%Y%m%dT%H%M)
# if force spt version, ignore all version checks and disable user folder backup
force_spt_version=${FORCE_SPT_VERSION:=}
forced_spt_version_archive=SPT-${force_spt_version}.7z

nodejs_spt_data_dir=$mounted_dir/SPT_Data
spt_nodejs_core_config=$nodejs_spt_data_dir/Server/configs/core.json
spt_dir=$mounted_dir/SPT
spt_data_dir=$spt_dir/SPT_Data
enable_spt_listen_on_all_networks=${LISTEN_ALL_NETWORKS:-false}


fika_version=${FIKA_VERSION:-1.0.2}
install_fika=${INSTALL_FIKA:-false}
fika_backup_dir=$backup_dir/fika/$(date +%Y%m%dT%H%M)
fika_config_path=assets/configs/fika.jsonc
fika_mod_dir=$spt_dir/user/mods/fika-server
fika_artifact=Fika.Server.Release.$fika_version.zip
fika_release_url="https://github.com/project-fika/Fika-Server-CSharp/releases/download/v$fika_version/$fika_artifact"

auto_update_spt=${AUTO_UPDATE_SPT:-false}
auto_update_fika=${AUTO_UPDATE_FIKA:-false}

take_ownership=${TAKE_OWNERSHIP:-true}
change_permissions=${CHANGE_PERMISSIONS:-true}
enable_profile_backup=${ENABLE_PROFILE_BACKUP:-true}

num_headless_profiles=${NUM_HEADLESS_PROFILES:+"$NUM_HEADLESS_PROFILES"}

install_other_mods=${INSTALL_OTHER_MODS:-false}

enforce_spt_4_structure() {
    # detect SPT 4 files in serverfiles root, if exists move everything into SPT/ subdirectory
    if [[ -f $mounted_dir/$spt_binary ]]; then
        echo "Enforcing SPT 4.0 structure"
        mkdir -p $spt_dir
        for item in $mounted_dir/*; do
            base_item=$(basename "$item")
            if [ "$base_item" != "SPT" ]; then
                mv "$item" $spt_dir
            fi
        done
    fi
}

# Deprecated
# TODO Remove this functionality, it is now built into SPT Server
start_crond() {
    echo "Enabling profile backups"
    /etc/init.d/cron start
}

create_running_user() {
    echo "Checking running user/group: $uid:$gid"
    getent group $gid || groupadd -g $gid spt
    if [[ ! $(id -un $uid) ]]; then
        echo "User not found, creating user 'spt' with id $uid"
        useradd --create-home -u $uid -g $gid spt
    fi
}

# Check that
# - options passed in are valid
# - Mounted directory is available
# - SPT version >= 4.0.0
# - SPT version is up to date
# - Fika version is up to date
validate() {
    if [[ ${num_headless_profiles:+1} && ! $num_headless_profiles =~ ^[0-9]+$ ]]; then
        echo "NUM_HEADLESS_PROFILES must be a number.";
        exit 1
    fi

    # Must mount /opt/server directory, otherwise the serverfiles are in container and there's no persistence
    if [[ ! $(mount | grep $mounted_dir) ]]; then
        echo "Please mount a volume/directory from the host to $mounted_dir. This server container must store files on the host."
        echo "You can do this with docker run's -v flag e.g. '-v /path/on/host:/opt/server'"
        echo "or with docker-compose's 'volumes' directive"
        exit 1
    fi

    # Validate SPT version
    # If we have sptVersion in the core config, this means this existing server <= SPT v3
    # If existing SPT major version is less than 4, existing files are not compatible
    echo "Validating SPT version"
    if [[ -d $nodejs_spt_data_dir && -f $spt_nodejs_core_config ]]; then
        existing_spt_version=$(jq -r '.sptVersion' $spt_nodejs_core_config)
        if [[ $existing_spt_version != "null" && $existing_spt_version != "$spt_version" ]]; then
            echo "  ==================="
            echo "  === FATAL ERROR ==="
            echo ""
            echo "  The existing server files mounted to /opt/server appear to be from SPT Server version $existing_spt_version"
            echo "  This image is ONLY compatible with SPT version > 4.0.0"
            echo "  and cannot automatically update your existing server files."
            echo "  Please remove these files or mount a different empty directory and restart this container to reinstall SPT"
            echo ""
            echo "  ==================="
            exit 1
        fi
    fi

    enforce_spt_4_structure

    if [[ -d $spt_data_dir ]]; then
        # Grab version from binary using exiftool
        existing_spt_version=$(exiftool -s -s -s -ProductVersion $spt_dir/SPT.Server.dll | cut -d '-' -f 1)
        if [[ -n ${force_spt_version} ]]; then
            # Force download SPT archive and install, do not backup or validate
            force_install_spt
        elif [[ $existing_spt_version != "$spt_version" ]]; then
            try_update_spt $existing_spt_version
        fi

        # Validate fika version
        if [[ -d $fika_mod_dir && $install_fika == "true" ]]; then
            echo "Validating Fika version"
            existing_fika_version=$(exiftool -s -s -s -ProductVersion $fika_mod_dir/FikaShared.dll | cut -d '-' -f 1 | cut -d '+' -f 1)
            if [[ "$existing_fika_version" != $fika_version ]]; then
                try_update_fika "$existing_fika_version"
            fi
        fi
    fi
}

make_and_own_spt_dirs() {
    mkdir -p $spt_dir/user/mods
    mkdir -p $spt_dir/user/profiles
    change_owner
    set_permissions
}

change_owner() {
    if [[ "$take_ownership" == "true" ]]; then
        echo "Changing owner of serverfiles to $uid:$gid"
        chown -R ${uid}:${gid} $mounted_dir
    fi
}

set_permissions() {
    if [[ "$change_permissions" == "true" ]]; then
        echo "Changing permissions of server files to user+rwx, group+rwx, others+rx"
        # owner(u), (g)roup, (o)ther
        # (r)ead, (w)rite, e(x)ecute
        chmod -R u+rwx,g+rwx,o+rx $mounted_dir
    fi
}

set_timezone() {
    # If the TZ environment variable has been set, use it
    if [[ ! -z "${TZ}" ]]; then
        # Update the /etc/timezone to the specified time zone
        echo $TZ > /etc/timezone
    else
        # Grab the hour from the date command to compare against later
        before_date_hour=$(date +"%H")

        # Set TZ to the /etc/timezone, either mounted or the default from the container
        TZ=$(cat /etc/timezone)
    fi

    # Force update the symlink
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime

    # If there was actually a change in the timezone or TZ was specified (accounted for here when before_date_hour is not set above)
    if [[ $before_date_hour != $(date +"%H") ]]; then
        echo "Timezone set to $TZ";
    fi
}

########
# Fika #
########
install_fika_mod() {
    echo "Installing Fika servermod version $fika_version"
    # Assumes fika_server.zip artifact contains user/mods/fika-server
    curl -sL $fika_release_url -O
    unzip -q $fika_artifact -d $mounted_dir/temp_fika/
    mv $mounted_dir/temp_fika/SPT/user/mods/fika-server $spt_dir/user/mods/
    rm -r $mounted_dir/temp_fika
    rm $fika_artifact
    echo "Installation complete"
}

backup_fika() {
    mkdir -p $fika_backup_dir
    cp -r $fika_mod_dir $fika_backup_dir
}

try_update_fika() {
    if [[ "$auto_update_fika" != "true" ]]; then
        echo "Fika Version mismatch: Fika install requested but existing fika mod server is v$existing_fika_version while this image expects $fika_version"
        echo "If you wish to use this container to update your Fika server mod, set AUTO_UPDATE_FIKA to true"
        echo "Aborting"
        exit 1
    fi

    echo "Updating Fika servermod in place, from $1 to $fika_version"
    # Backup entire fika servermod, then delete and update servermod
    backup_fika
    rm -r $fika_mod_dir
    install_fika_mod
    # restore config
    mkdir -p $fika_mod_dir/assets/configs
    existing_fika_config=$fika_backup_dir/fika-server/$fika_config_path
    if [[ -f $existing_fika_config ]]; then
        cp $existing_fika_config $fika_mod_dir/$fika_config_path
    fi
    echo "Successfully updated Fika from $1 to $fika_version"
}

set_num_headless_profiles() {
    if [[ ${num_headless_profiles:+1} && -f $fika_mod_dir/$fika_config_path ]]; then
        echo "Setting number of headless profiles to $num_headless_profiles"
        modified_fika_jsonc="$(jq --arg jq_num_headless_profiles $num_headless_profiles '.headless.profiles.amount=($jq_num_headless_profiles | tonumber)' $fika_mod_dir/$fika_config_path)" && echo -E "${modified_fika_jsonc}" > $fika_mod_dir/$fika_config_path
    fi
}

#######
# SPT #
#######
install_spt() {
    # Remove the server files, since databases tend to be different between versions
    rm -rf $spt_data_dir

    # If FORCE_SPT_VERSION is set, download and override the built in version with provided version
    # Archive stored in root mounted folder. Supports user manually supplying the release archive
    if [[ -n ${force_spt_version} ]]; then
        echo "Forcing SPT version to $force_spt_version"
        # check if archive already exists, and extract if so
        if [[ ! -f ${build_dir}/${forced_spt_version_archive} ]]; then
            curl -sL "https://spt-releases.modd.in/SPT-${force_spt_version}.7z" -o ${forced_spt_version_archive}
        fi
        7zz x ${forced_spt_version_archive} -o${mounted_dir} -aoa 
    else
        cp -r $build_dir/* $mounted_dir
    fi
    make_and_own_spt_dirs
}

# TODO Anticipate BepInEx too, for Corter-ModSync
backup_spt_user_dirs() {
    mkdir -p $spt_backup_dir
    cp -r $spt_dir/user $spt_backup_dir/
}

force_install_spt() {
    echo "!! Forcing SPT version to $force_spt_version"
    echo "!! SPT auto-update is disabled"
    install_spt
}

try_update_spt() {
    if [[ "$auto_update_spt" != "true" ]]; then
        echo "SPT Version mismatch: existing server files are SPT $existing_spt_version while this image expects $spt_version"
        echo "If you wish to use this container to update your SPT Server files, set AUTO_UPDATE_SPT to true"
        echo "Aborting"
        exit 1
    fi

    echo "Updating SPT in-place, from $1 to $spt_version"
    # Backup SPT, install new version, then halt
    backup_spt_user_dirs
    install_spt
    echo "SPT update completed. We moved from $1 to $spt_version"
    echo "  "
    echo "  ==============="
    echo "  === WARNING ==="
    echo ""
    echo "  The user/ folder has been backed up to $spt_backup_dir, but otherwise has been LEFT UNTOUCHED in the server dir."
    echo "  Please verify your existing mods and profile work with this new SPT version! You may want to delete the mods directory and start from scratch"
    echo "  Restart this container to bring the server back up"
    echo ""
    echo "  ==============="
    exit 0
}

spt_listen_on_all_networks() {
    # Changes the ip and backendIp to 0.0.0.0 so that the server will listen on all network interfaces.
    http_json=$spt_data_dir/configs/http.json
    modified_http_json="$(jq '.ip = "0.0.0.0" | .backendIp = "0.0.0.0"' $http_json)" && echo -E "${modified_http_json}" > $http_json
    # If fika server config exists, modify that too
    if [[ -f "$fika_mod_dir/$fika_config_path" ]]; then
        echo "Setting listen all networks in Fika SPT config override"
        modified_fika_jsonc="$(jq '.server.SPT.http.ip = "0.0.0.0" | .server.SPT.http.backendIp = "0.0.0.0"' $fika_mod_dir/$fika_config_path)" && echo -E "${modified_fika_jsonc}" > $fika_mod_dir/$fika_config_path
    fi
}

##############
# Other Mods #
##############

install_requested_mods() {
    # Run the download & install mods script
    echo "Downloading and installing other mods"
    /usr/bin/download_unzip_install_mods $spt_dir
}

##############
# Run it All #
##############

validate

# If no server binary in this directory, copy our built files in here and run it once
if [[ ! -f "$spt_dir/$spt_binary" ]]; then
    echo "Server files not found, initializing first boot..."
    install_spt
else
    echo "Found server files, skipping init"
fi

# Install listen on all interfaces is requested.
if [[ "$enable_spt_listen_on_all_networks" == "true" ]]; then
    spt_listen_on_all_networks
fi

# Install fika if requested. Run each boot to support installing in existing serverfiles that don't have fika installed
if [[ "$install_fika" == "true" ]]; then
    if [[ ! -d $fika_mod_dir ]]; then
        echo "No Fika server mod detected and install was requested. Beginning installation."
        install_fika_mod
    else 
        echo "Fika install requested but Fika server mod dir already exists, skipping Fika installation"
    fi
fi

set_num_headless_profiles

if [[ "$install_other_mods" == "true" ]]; then
    install_requested_mods
fi

if [[ "$enable_profile_backup" == "true" ]]; then
    echo "  ==============="
    echo "  === WARNING ==="
    echo ""
    echo "  This profile backup feature will be deprecated in the near future"
    echo "  since it is now built into SPT Server"
    echo "  ==============="
    start_crond
fi

create_running_user

# Own mounted files as running user
change_owner
set_permissions

set_timezone

su - $(id -nu $uid) -c "cd $spt_dir && ./$spt_binary"
