# fika-spt-server-docker
Clean and easy way to run SPT + Fika server in docker, with the flexibility to modify server files as you wish

## Why?
Existing SPT Dockerfiles seem to leave everything, including building the image with the right sources, up to the user to manage.
I aim to provide a fully packaged SPT Docker image with optional Fika mod that is as plug-and-play as possible. All you need is a working docker install,
and to supply a directory to contain your serverfiles, or an existing server directory. The image has everything else you need to run an SPT Server,
with Fika if desired.

## Features
- Reuse an existing installation of SPT! Just mount your existing SPT server folder
- Prepackaged images versioned by SPT version. Images are hosted in ghcr and come prebuilt with a working SPT server binary, and the latest Fika servermod is downloaded and installed on container startup
- Configurable running user and ownership of server files
- Auto updates only if configured

# Releases
The image build is triggered off commits to master and hosted on ghcr
```
docker pull ghcr.io/zhliau/fika-spt-server-docker:latest
```

# Running
See the example docker-compose
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

If you want to run as a different user than root, set UID and GID
```yaml
services:
  fika-server:
    image: ghcr.io/zhliau/fika-spt-server-docker:latest
    # ...
    environment:
      # Provide the uid/gid of the user, or it will default to 0 (root)
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

# Updating SPT/Fika versions
TODO
- Change the image tag or re-pull the existing one
- Run the container

# Environment Variables
## Optional
| Env var        | Description |
| -------------- | ----------- |
| `UID`          | The userID to use to run the server binary. This user is created in the container on runtime |
| `GID`          | The groupID to assign when creating the user running the server binary. This has no effect if no user is created |
| `INSTALL_FIKA` | Whether you want the container to automatically install/update fika servermod for you |
| `FIKA_VERSION` | Override the fika version string to grab the server release from. The release URL is formatted as `https://github.com/project-fika/Fika-Server/releases/download/$FIKA_VERSION/fika-server.zip`


# Troubleshooting
## Why are there files owned by root in my server files?
If you don't want the root user to run SPT server, make sure you provide a userID/groupID to the image to use to run the server.
If none are provided, it defaults to uid 0 which is the root user.
Running the server with root will mean anything the server writes out is created by the root user.

## Development
### Building
```
# Server binary built using SPT Server 3.9.8 git tag, image tagged as fika-spt-server:1.0
$ VERSION=1.0 SPT_SHA=3.9.8 ./build
```
