#!/bin/bash -e

mounted_dir=/opt/server
profiles_dir=$mounted_dir/user/profiles
timestamp=$(date +%Y%m%dT%H%M)
backup_dir=$mounted_dir/backups/profiles/$timestamp

if [[ ! $(mount | grep $mounted_dir) ]]; then
    echo "Failed to run profile backup! Server directory not mounted!" >> /proc/1/fd/1
    exit 1
fi

echo "Backing up profiles. Destination is $backup_dir" >> /proc/1/fd/1
mkdir -p $backup_dir
# Backup profiles
cp -r $profiles_dir $backup_dir
echo "Backup complete." >> /proc/1/fd/1
