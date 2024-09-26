#!/bin/bash -e

build_dir=/opt/build
mounted_dir=/opt/server
spt_binary=SPT.Server.exe
uid=${UID:-1000}
gid=${GID:-1000}

install_fika=${INSTALL_FIKA:-false}
fika_mod_dir=fika-server
fika_version=v2.2.8
fika_artifact=fika-server.zip
fika_release_url="https://github.com/project-fika/Fika-Server/releases/download/$fika_version/$fika_artifact"

make_and_own() {
    mkdir -p $mounted_dir/user/mods
    mkdir -p $mounted_dir/user/profiles
    chown -R ${uid}:${gid} $mounted_dir
}

create_running_user() {
    echo "Checking running user/group: $uid:$gid"
    getent group $gid || groupadd -g $gid spt
    if [[ ! $(id -un $uid) ]]; then
        echo "User not found, creating user 'spt' with id $uid"
        useradd --create-home -u $uid -g $gid spt
    fi
}

get_and_install_fika() {
    echo "Installing Fika servermod version $fika_version"
    # Assumes fika_server.zip artifact contains user/mods/fika-server
    curl -sL $fika_release_url -O
    unzip -q $fika_artifact -d $mounted_dir
    rm $fika_artifact
}

# Must mount /opt/server directory, otherwise the serverfiles are in container and there's no persistence
if [[ ! $(mount | grep $mounted_dir) ]]; then
    echo "Please mount a volume/directory from the host to $mounted_dir. The server must store files on the host."
    echo "You can do this with docker run's -v flag e.g. '-v /path/on/host:/opt/server'"
    echo "or with docker-compose's 'volumes' directive"
    exit 1
fi

# If no server binary in this directory, copy our built files in here and run it once
if [[ ! -f "$mounted_dir/$spt_binary" ]]; then
    echo "Server files not found, initializing first boot..."
    cp -r $build_dir/* $mounted_dir
    make_and_own
else
    echo "Found server files, skipping init"
fi

# TODO should fika install be first time run only?
if [[ "$install_fika" == "true" ]]; then
    if [[ ! -d $mounted_dir/user/mods/$fika_mod_dir ]]; then
        get_and_install_fika
    else 
        echo "Fika install requested but fika servermod already exists, skipping installation"
    fi
fi

create_running_user
# Own mounted files as running user
# TODO Do we want to do this? Would it be annoying if user expects files ownership not to change?
# downside is we are running as a specific user so any files created by the server binary will be owned by the running user
chown -R ${uid}:${gid} $mounted_dir

su - $(id -nu $uid) -c "cd $mounted_dir && ./SPT.Server.exe"
