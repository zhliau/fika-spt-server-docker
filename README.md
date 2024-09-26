# fika-spt-server
Clean and easy way to run SPT + Fika server in docker

## Why?
Existing dockerfiles seem to leave building the image up to the user. I aim to provide a fully packaged SPT docker image that is as plug-and-play as possible. All you need 
to supply is a directory containing your serverfiles, and the image has everything else you need to run.

## Features
- Reuse existing installation of SPT! Just mount your existing SPT server folder
- Prepackaged images versioned by SPT version. Images are hosted in ghcr and come prebuilt with a working SPT server binary, and the latest Fika servermod is downloaded and installed on container startup
- Configurable running user and ownership of entire server directory, and does not touch existing files if detected. No more root owned directories!

# Running
See the example docker-compose

## Development
### Building
```
# Image built using SPT Server 3.9.8 git tag, image tagged as fika-spt-server:1.0
$ VERSION=1.0 SPT_SHA=3.9.8 ./build
```
