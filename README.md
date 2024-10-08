# fika-spt-server-docker
🐳 Clean and easy way to run SPT + Fika server in docker, with auto-updates, profile backups, and the flexibility to modify server files as you wish 🐳

# 🤔 Why?
Existing SPT Dockerfiles seem to leave everything, including building the image with the right sources, up to the user to manage.
This image aims to provide a fully pre-packaged SPT Docker image with optional Fika mod that is as plug-and-play as possible. All you need is
- A working docker installation
- A directory to contain your serverfiles, or an existing server directory.

That's it! The image has everything else you need to run an SPT Server, with Fika if desired.

- [🪄 Features](#-features)
- [🥡 Releases](#-releases)
- [🛫 Running](#-running)
  * [docker](#docker)
  * [docker-compose](#docker-compose)
  * [Using an existing installation](#using-an-existing-installation)
  * [Updating SPT/Fika versions](#updating-sptfika-versions)
    + [When Fika server mod is updated for the same SPT version](#when-fika-server-mod-is-updated-for-the-same-spt-version)
    + [When SPT updates](#when-spt-updates)
- [Environment Variables](#environment-variables)
- [FAQ](#faq)
  * [Why are there files owned by root in my server files?](#why-are-there-files-owned-by-root-in-my-server-files)
  * [Can I use this without Fika?](#can-i-use-this-without-fika)
  * [I am running this container on Linux, why does the server output show errors regarding Windows-like paths?](#i-am-running-this-container-on-linux-why-does-the-server-output-show-errors-regarding-windows-like-paths-eg-csnapshot)
  * [Server starts but I cannot connect to it](#the-server-starts-but-i-cannot-connect-to-it-and-it-doesnt-seem-to-be-listening-on-port-6969)
- [Development](#development)
  * [Building](#building)



# 🪄 Features
- 📦 Prepackaged images versioned by SPT version e.g. `fika-spt-server-docker:3.9.8` for SPT `3.9.8`. Images are hosted in ghcr and come prebuilt with a working SPT server binary, and the latest compatible Fika servermod is downloaded and installed on container startup if enabled.
- ♻️ Reuse an existing installation of SPT! Just mount your existing SPT server folder
- 💾 Automatic profile backups by default! Profiles are copied to a backup folder every day at 00:00 UTC
- 🔒 Configurable running user and ownership of server files. Control file ownership from the host, or let the container take ownership to ease permissions issues.
- ⬆️ Optionally auto updates SPT or Fika if we detect a version mismatch between container expected version and installed version

# 🥡 Releases
The image build is triggered off release tags and hosted on ghcr
```
docker pull ghcr.io/zhliau/fika-spt-server-docker:latest
```
Check the pane on the right for the different version tags available, if you don't want to use the latest SPT release.

# 🛫 Running
### docker
```
docker run --name fika-server \
  -v /path/to/server/files:/opt/server \
  -p 6969:6969 \
  ghcr.io/zhliau/fika-spt-server-docker:3.9.8 
```

### docker-compose
See the example docker-compose for a more complete definition.

Minimal usage
```yaml
services:
  fika-server:
    image: ghcr.io/zhliau/fika-spt-server-docker:latest
    ports:
      - 6969:6969
    volumes:
      # Set this to an empty directory, or a directory containing your existing SPT server files
      - ./path/to/server/files:/opt/server
```

If you want to run the server as a different user than root, set UID and GID
```yaml
services:
  fika-server:
    image: ghcr.io/zhliau/fika-spt-server-docker:latest
    # ...
    environment:
      # Provide the uid/gid of the user to run the server, or it will default to 0 (root)
      # You can get your host user's uid/gid by running the id command
      - UID=1000
      - GID=1000
```

If you want to automatically install Fika, set `INSTALL_FIKA` to `true`
```yaml
services:
  fika-server:
    image: ghcr.io/zhliau/fika-spt-server-docker:latest
    # ...
    environment:
      # ...
      - INSTALL_FIKA=true
```

## Using an existing installation
> [!WARNING]
> MAKE BACKUPS OF YOUR EXISTING SPT SERVER FILES BEFORE YOU DO THIS.

If you want to migrate to this docker image with an existing SPT install:
- Set your volume mount to your existing SPT server directory (the dir containing the SPT.Server.exe file)
- If you don't have Fika yet, you can provide a `INSTALL_FIKA` env var to tell the container to install the server mod for you
- Run the container, optionally specify if you want the container to auto update the SPT server files or fika server mod via the `AUTO_UPDATE_SPT` and `AUTO_UPDATE_FIKA` env vars

## Updating SPT/Fika versions
This image comes built with a copy of SPT Server, versioned by the image's version tag.
It also is set to automatically pull the appropriate Fika server mod version, if required.
Enable auto updates by setting the correct environment variables
```yaml
services:
  fika-server:
    image: ghcr.io/zhliau/fika-spt-server-docker:latest
    # ...
    environment:
      # ...
      - AUTO_UPDATE_SPT=true
      - AUTO_UPDATE_FIKA=true
      - INSTALL_FIKA=true # Required if you want to auto-update Fika server mod too
```

### When Fika server mod is updated for the same SPT version
This image will hopefully be updated in a timely manner to the new Fika server mod version, and the image will be rebuilt with the same SPT version tag. Thus, all you will need to do is
- Pull the image again with `docker pull` or `docker-compose pull`
- Bring up the container again with `docker run` or `docker-compose up`

The container will validate your Fika server mod version matches the image's expected version, and if not it will
- Back up the entire Fika server mod including configs to a `backups/fika` directory in the mounted server directory
- Install the expected fika server mod version
- Copy your old fika.jsonc config into the server mod config directory

> [!NOTE]
> The existing config is not guaranteed to work across versions. Expect to do some troubleshooting here especially if config options are added/removed in the new Fika server mod version.

### When SPT updates
A new image will be tagged with the new SPT version number, and thus you will need to
- Update the image version tag e.g. `fika-spt-server-docker:3.9.8` to `fika-spt-server-docker:3.10.0`
- Pull the new image with `docker pull` or `docker-compose pull`
- Bring up the container again with `docker run` or `docker-compose up`

The image will validate that your SPT version in the serverfiles matches the image's expected SPT version, and if not it will
- Back up the entire `user/` directory to a `backups/spt/` directory in the mounted server directory
- Install the right version of SPT in-place.

> [!NOTE]
> The user directory in your existing SPT server files is left untouched! Please make sure that you validate that the SPT version you are running works with your installed mods and profiles!
> You may want to start by removing all mods and validating them one by one

# Environment Variables
None of these env vars are required, but they may be useful.
| Env var                   | Default | Description |
| ------------------------- | ------- | ----------- |
| `UID`                     | 1000    | The userID to use to run the server binary. This user is created in the container on runtime |
| `GID`                     | 1000    | The groupID to assign when creating the user running the server binary. This has no effect if no UID is provided and no user is created |
| `INSTALL_FIKA`            | false   | Whether you want the container to automatically install/update fika servermod for you |
| `FIKA_VERSION`            | v2.2.8  | Override the fika version string to grab the server release from. The release URL is formatted as `https://github.com/project-fika/Fika-Server/releases/download/$FIKA_VERSION/fika-server.zip` |
| `AUTO_UPDATE_SPT`         | false   | Whether you want the container to handle updating SPT in your existing serverfiles |
| `AUTO_UPDATE_FIKA`        | false   | Whether you want the container to handle updating Fika server mod in your existing serverfiles |
| `TAKE_OWNERSHIP`          | true    | If this is set to false, the container will not change file ownership of the server files. Make sure the running user has permissions to access these files |
| `ENABLE_PROFILE_BACKUP`   | true    | If this is set to false, the cron job that handles profile backups will not be enabled |


# FAQ
### Why are there files owned by root in my server files?
If you don't want the root user to run SPT server, make sure you provide a userID/groupID to the image to use to run the server.
If none are provided, it defaults to uid 0 which is the root user.
Running the server with root will mean anything the server writes out is created by the root user.

### Can I use this without Fika?
Yes! Simply set `INSTALL_FIKA` to `false` and the container will act as an ordinary SPT server container. Everything else including the autoupdate capability for SPT remains unchanged.

### I am running this container on Linux, why does the server output show errors regarding Windows-like paths? e.g. `C:\snapshot\...`.
If you are reusing an existing SPT server that was previously running on Windows, you will need to delete the contents of your `/user/cache` folder.

### The server starts, but I cannot connect to it, and it doesn't seem to be listening on port 6969?
Set the values of `ip` and `backendIp` in `SPT_Data/Server/configs/http.json` to `0.0.0.0`, to get the SPT server to listen on all interfaces. The file should look similar to this:
```
{
    "ip": "0.0.0.0",
    "port": 6969,
    "backendIp": "0.0.0.0",
    "backendPort": 6969,
    "webSocketPingDelayMs": 90000,
    "logRequests": true,
    "serverImagePathOverride": {}
}
```

# Development
### Building
```
# Server binary built using SPT Server 3.9.8 git tag, image tagged as fika-spt-server:1.0
$ VERSION=1.0 SPT_SHA=3.9.8 ./build
```
