#!/bin/bash -e

BUILD_DIR=/opt/build
MOUNTED_DIR=/opt/server
SPT_BINARY=SPT.Server.exe

make_and_own() {
    mkdir -p $MOUNTED_DIR/user/mods
    mkdir -p $MOUNTED_DIR/user/profiles

    # TODO Make this configurable
    # Do not have root own this mounted dir, this sucks for the host
    chown -R 1000:1000 $MOUNTED_DIR
}

# Must mount /opt/server directory, otherwise the server will spin up and there's no way you can modify it
if [[ ! $(mount | grep $MOUNTED_DIR) ]]; then
    echo "Please mount a volume/directory from the host to $MOUNTED_DIR. The server must store files on the host."
    echo "You can do this with docker run's -v flag e.g. '-v /path/on/host:/opt/server'"
    exit 1
fi

# If no server files in this directory, copy our built files in here and run it once
if [[ ! -f "$MOUNTED_DIR/$SPT_BINARY" ]]; then
    echo "Server files not found, initializing first boot..."
    cp -r $BUILD_DIR/* $MOUNTED_DIR
    make_and_own
fi

./SPT.Server.exe
