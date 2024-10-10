#!/bin/bash

# Download and install mods based on provided list of urls
# It does NOT check if the mod was actually installed or what version,it only checks if the url has been downloaded before

# Assumes mods are packaged as 'BepInEx/MOD_NAME' and/or 'user/mods/MOD_NAME' and moves them to their appropriate locations
# It will also do the following:
# - move any bare .dll files to BepInEx/plugins
# - move any .txt, .md. and .exe files to the root of the mounted directory
# - move any remaining downloads and extracted files to the mod_download directory

# Dependencies
# - aria2: download files
#   - using instead of wget to download multiple files concurrently
#   - using instead of curl to better handle google drive downloard using --content-disposition flag
# - unzip: extract .zip files
# - 7z: extract .7z files
# - tar: extract .tar.* files


################################## Variables and Setup Functions ##################################

# Get the passed in mounted_dir variable
mounted_dir=$1

mod_download_dirname=mod_download
mod_download_dir=$mounted_dir/$mod_download_dirname
mod_download_remains_relative_dir=$mod_download_dirname/remains
mod_download_remains_dir=$mounted_dir/$mod_download_remains_relative_dir

plugins_mod_dir=$mounted_dir/BepInEx/plugins
user_mod_dir=$mounted_dir/user/mods

# File for mod urls the user requests to be downloaded
mod_urls_to_download_filename=mod_urls_to_download.txt
mod_urls_to_download_filepath=$mod_download_dir/$mod_urls_to_download_filename

# File to keep track of the mod urls that have been downloaded.
mod_urls_downloaded_filepath=$mod_download_dir/mod_urls_downloaded.txt

# File to output logs, including wget and upzip commands.
download_unzip_install_logs_relative_filepath=$mod_download_dirname/download_unzip_install_mods.log
download_unzip_install_logs_filepath=$mounted_dir/$download_unzip_install_logs_relative_filepath

# Download to and unzip in the tmp directory
tmp_download_dir=/tmp/download_mods
tmp_downloaded_dir=$tmp_download_dir/downloaded
tmp_extracted_dir=$tmp_download_dir/extracted
new_urls_to_download_filepath=$tmp_download_dir/new_urls_to_download.txt

# Create the download dir
make_download_dirs_and_files() {
    # Create the directory to hold the files & logs relataed to downloading mods
    mkdir -p $mod_download_dir

    # Create the downloaded mods file it if it does not exist.
    touch $mod_urls_downloaded_filepath

    # Create the tmp download and unzip directories.
    mkdir -p $tmp_download_dir
    touch $new_urls_to_download_filepath
}


####################################### Download Functions ########################################

# Checks the mod_urls_downloaded_filepath to see if the mod has already been downloaded.
check_url_and_queue_to_download() {
    local url=$1
    # If the url is already in the url file
    if ! (cat $mod_urls_downloaded_filepath | grep -q $url); then
        echo "  $url not found. Queuing for download" >> $download_unzip_install_logs_filepath

        # Check if it's in the new urls to be downloaded file and append it if it's not already there.
        # This would account for the url being duplicated anywhere so that it's only downloaded once.
        if ! (cat $new_urls_to_download_filepath | grep -q $url); then
            echo $url >> $new_urls_to_download_filepath
        fi
    fi
}

# Iterate over any URLs in the env variable and file and call the compile_urls_to_download function for each.
check_requested_urls() {
    echo "Checking for new urls in MOD_URLS_TO_DOWNLOAD environmet variable" >> $download_unzip_install_logs_filepath
    if [ ! -z "${MOD_URLS_TO_DOWNLOAD}" ]; then
        for url in $MOD_URLS_TO_DOWNLOAD; do
            check_url_and_queue_to_download $url
        done
    else
        echo "  MOD_URLS_TO_DOWNLOAD environment variable is blank" >> $download_unzip_install_logs_filepath
    fi

    echo "Checking for new urls in $mod_urls_to_download_filename" >> $download_unzip_install_logs_filepath
    if [ -f "$mod_urls_to_download_filepath"  ] && [ ! -z "$(cat ${mod_urls_to_download_filepath})" ]; then
        while read url; do
            check_url_and_queue_to_download $url
        done <$mod_urls_to_download_filepath
    else
        echo "$mod_urls_to_download_filename does not exist or is empty" >> $download_unzip_install_logs_filepath
    fi
}

download_new_urls() {
    check_requested_urls

    # If there are any new urls to download.
    if [ -f "$new_urls_to_download_filepath"  ] && [ ! -z "$(cat ${new_urls_to_download_filepath})" ]; then
        mkdir -p $tmp_downloaded_dir
        echo "  Finished compiling url download list. Starting downloads" | tee -a $download_unzip_install_logs_filepath
        
        aria2c -q --content-disposition-default-utf8 true \
        --input-file=$new_urls_to_download_filepath \
        --dir=$tmp_downloaded_dir \
        --log-level=notice \
        --log=$download_unzip_install_logs_filepath

        # Once all downloads are complete, append the downloaded files list to the master list for .
        cat $new_urls_to_download_filepath >> $mod_urls_downloaded_filepath
    else
        echo "  No new urls queued up. Nothing to download" >> $download_unzip_install_logs_filepath
    fi
}


######################################### Unizp Functions #########################################
# Unzip functions for all the .zip, .7z, and tar/tar.gz files using their respective commands.

extract_zip_files() {
    # If any .zip files were downloaded, unzip all of them.
    if (ls $tmp_downloaded_dir/*.zip &> /dev/null); then
        echo "Unzipping the downloaded zip files" >> $download_unzip_install_logs_filepath
        for z in $tmp_downloaded_dir/*.zip
        do
            echo "  Unzipping $z" >> $download_unzip_install_logs_filepath
            # -q to quiet output a bit
            # -d to specify directory (which will be deleted during cleanup below)
            # &>> to redirect all normal and error outputs to log file as append
            unzip -q "$z" -d $tmp_extracted_dir &>> $download_unzip_install_logs_filepath;
            # remove it once downloaded
            rm "$z"
        done
        echo "  All zip files extracted" >> $download_unzip_install_logs_filepath
    else
        echo "  No zip files downloaded" >> $download_unzip_install_logs_filepath
    fi
}

extract_7zip_files() {
    # If any .7z files were downloaded, unzip all of them.
    if (ls $tmp_downloaded_dir/*.7z &> /dev/null); then
        echo "Unzipping the downloaded 7zip files" >> $download_unzip_install_logs_filepath
        for z in $tmp_downloaded_dir/*.7z
        do
            echo "  Unzipping $z" >> $download_unzip_install_logs_filepath
            # -o to specify directory (which will be deleted during cleanup below).
            # &>> to redirect all normal and error outputs to log file as append
            7zz x "$z" -o$tmp_extracted_dir &>> $download_unzip_install_logs_filepath;
            # remove it once downloaded
            rm "$z"
        done
        echo "  All 7z files extracted" >> $download_unzip_install_logs_filepath
    else
        echo "  No 7zip files downloaded" >> $download_unzip_install_logs_filepath
    fi
}

extract_tar_files() {
    # If any .tar* files were downloaded, unzip all of them.
    if (ls $tmp_downloaded_dir/*.tar* &> /dev/null); then
        echo "Unzipping the downloaded tar files" >> $download_unzip_install_logs_filepath

        # The tar command requires that the target directory exists so create it (-p for no error if it exists).
        mkdir -p $tmp_extracted_dir
        for z in $tmp_downloaded_dir/*.tar*
        do
            echo "  Unzipping $z" >> $download_unzip_install_logs_filepath
            # -C to specify directory (which will be deleted during cleanup below).
            # &>> to redirect all normal and error outputs to log file as append
            tar -xvf "$z" -C $tmp_extracted_dir &>> $download_unzip_install_logs_filepath;
            # remove it once downloaded
            rm "$z"
        done
        echo "  All tar files extracted" >> $download_unzip_install_logs_filepath
    else
        echo "  No tar files downloaded" >> $download_unzip_install_logs_filepath
    fi
}

extract_downloads() {
    extract_zip_files
    extract_7zip_files
    extract_tar_files
}

################################## "Install" & Cleanup Functions ##################################
# "Install", ie just move the server mods, BepInEx plugins directories/dlls to the proper locations
# Move everything else to a directory for the user to handle manually

move_extracted_files() {
    # Create the needed destination mod directories if they don't already exist
    mkdir -p $plugins_mod_dir
    mkdir -p $user_mod_dir

    # Copy the BepInEx directory to where it needs to go. Some mods have the p in plugins capitalized
    cp -rf $tmp_extracted_dir/BepInEx/plugins/* $plugins_mod_dir 2> /dev/null
    cp -rf $tmp_extracted_dir/BepInEx/Plugins/* $plugins_mod_dir 2> /dev/null
    rm -rf $tmp_extracted_dir/BepInEx 2> /dev/null

    # Copy the user/mods directory to where it needs to go and the cleanup 
    cp -rf $tmp_extracted_dir/user/* $mounted_dir/user 2> /dev/null
    rm -rf $tmp_extracted_dir/user 2> /dev/null

    # Move any txt or md files (usually with licenses and readme's) and executables (like ModSync and SVM) to the parent directory
    cp $tmp_extracted_dir/*.txt $mounted_dir 2> /dev/null
    rm $tmp_extracted_dir/*.txt 2> /dev/null
    
    cp $tmp_extracted_dir/*.md $mounted_dir 2> /dev/null
    rm $tmp_extracted_dir/*.md 2> /dev/null
    
    cp $tmp_extracted_dir/*.exe $mounted_dir 2> /dev/null
    rm $tmp_extracted_dir/*.exe 2> /dev/null
}

move_remaining_downloaded_files() {
    # If there are any loose dll files, move them to BepInEx/plugins.
    cp $tmp_downloaded_dir/*.dll $plugins_mod_dir 2> /dev/null
    rm $tmp_downloaded_dir/*.dll 2> /dev/null
}

cleanup_downloaded_and_extracted_files() {
    # If the downloaded or extracted directory is still not empty (ie there are still has things in it that this script has not already handled)
    if [ ! -z "$( ls -A $tmp_downloaded_dir )" ] || [ ! -z "$( ls -A $tmp_extracted_dir )" ]; then
        # move whatever remains in the extracted directory to allow the user to handle manually
        mkdir -p $mod_download_remains_dir

        cp -rf $tmp_extracted_dir/* $mod_download_remains_dir 2> /dev/null
        cp -rf $tmp_downloaded_dir/* $mod_download_remains_dir 2> /dev/null

        # Pipe echo to tee to output to stdout and append to log file.
        echo "  Some files could not be extracted and/or the script did not know where they go. They will be moved to $mod_download_remains_relative_dir"\
            | tee -a $download_unzip_install_logs_filepath
    fi
}

extract_downloads_and_install_mods() {
    # if the downloaded directory exists
    if [ -d "$tmp_downloaded_dir" ]; then
        echo "Extracting downloaded files" >> $download_unzip_install_logs_filepath
        extract_downloads

        echo "Installing mods" >> $download_unzip_install_logs_filepath

        # If there are any extracted files then the directory will be present
        if [ -d "$tmp_extracted_dir" ]; then
            move_extracted_files
        fi

        move_remaining_downloaded_files
        cleanup_downloaded_and_extracted_files

        echo "  Mod download and installation complete" >> $download_unzip_install_logs_filepath
        echo "  Mod download and installation complete. For complete logs see $download_unzip_install_logs_relative_filepath"
    else
        echo "  No files downloaded. No mods to install" | tee -a $download_unzip_install_logs_filepath
    fi
    rm -rf $tmp_download_dir 2> /dev/null
}


######################################### Run Everything ##########################################

# running this first so we know there is a log file to which to write
make_download_dirs_and_files

# Timestamp in the logs when this script is run
echo "Run $(date +'%d/%m/%Y %H:%M:%S')" >> $download_unzip_install_logs_filepath

download_new_urls
extract_downloads_and_install_mods
