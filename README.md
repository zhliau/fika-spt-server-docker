# fika-spt-server
Clean and easy way to run SPT + Fika server in docker

## Why?
Existing dockerfiles seem to leave building the image up to the user. I aim to provide a fully packaged SPT docker image that is as plug-and-play as possible. All you need 
to supply is a directory containing your serverfiles, and the image has everything else you need to run.

## Features
- Reuse existing installation of SPT! Just mount your existing SPT server folder
- Prepackaged images versioned by SPT version. Images are hosted in ghcr and come prebuilt with a working SPT server binary, and the latest Fika servermod is downloaded and installed on container startup
- Configurable running user and ownership of entire server directory, and does not touch existing files if detected. No more root owned directories!

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
    environment:
      # Provide the uid/gid of the user, or it will default to 0 (root)
      # You can get your host user's uid/gid by running the id command
      - UID=1000
      - GID=1000
    volumes:
      # Set this to the directory on your host containing your SPT server files
      - ./path/to/server/files:/opt/server

```

# Migrating
To migrate to a different version
- Copy your profiles somewhere else
- Update the version tag of the image
- Delete the SPT.Server.exe binary
- Run the container again

## Development
### Building
```
# Server binary built using SPT Server 3.9.8 git tag, image tagged as fika-spt-server:1.0
$ VERSION=1.0 SPT_SHA=3.9.8 ./build
```

### TODO
- [ ] Mark or detect server binary version and check for mismatch with image? Update if requested while leaving profiles/mods alone?
