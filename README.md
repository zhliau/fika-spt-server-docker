# fika-spt-server-docker
🐳 Clean and easy way to run SPT + Fika server in docker, with auto-updates, profile backups, and the flexibility to modify server files as you wish 🐳

# 🤔 Why?
Existing SPT Dockerfiles seem to leave everything, including building the image with the right sources, up to the user to manage.
This image aims to provide a fully pre-packaged SPT Docker image with optional Fika mod that is as plug-and-play as possible. All you need is
- A working docker installation
- A directory to contain your serverfiles, or an existing server directory.

That's it! The image has everything else you need to run an SPT Server, with Fika if desired.

> [!WARNING]
> With the release of SPT 4.0.0 and the rewrite to use C#, this image going forward will no longer support prior versions due to a significant change in how the image operates.
> 
> If you wish to use the LTS version of SPT (3.11.4), make sure you specify the image tag `fika-spt-server-docker:3.11.4` explicitly instead of using `latest`)

> [!WARNING]
> For users attempting to run version 4.0.0 of this docker image on ARM64 platform (i.e. Raspberry Pi), please note that this image will fail to run currently.
> Please see [this issue](https://github.com/zhliau/fika-spt-server-docker/issues/33) for more information

- [🪄 Features](#-features)
- [🥡 Releases](#-releases)
- [🛫 Running](#-running)
  * [docker](#docker)
  * [docker-compose](#docker-compose)
  * [Using an existing installation](#using-an-existing-installation)
  * [Updating SPT/Fika versions](#updating-sptfika-versions)
    + [When Fika server mod is updated for the same SPT version](#when-fika-server-mod-is-updated-for-the-same-spt-version)
    + [When SPT updates](#when-spt-updates)
    + [(NEW FOR SPT 4.0) Forcing SPT Version](#new-for-spt-40-forcing-spt-versions)
  * [Automatically download & install additional mods](#automatically-download--install-additional-mods)
    * [What it does](#what-it-does)
    * [How to use it](#how-to-use-it)
    * [Mod updates](#mod-updates)
  * [Time Zone Support](#time-zone)
- [🌐 Environment Variables](#-environment-variables)
- [💬 FAQ](#-faq)
  * [Why are there files owned by root in my server files?](#why-are-there-files-owned-by-root-in-my-server-files)
  * [Can I use this without Fika?](#can-i-use-this-without-fika)
  * [I am running this container on Linux, why does the server output show errors regarding Windows-like paths?](#i-am-running-this-container-on-linux-why-does-the-server-output-show-errors-regarding-windows-like-paths-eg-csnapshot)
  * [Server starts but I cannot connect to it](#the-server-starts-but-i-cannot-connect-to-it-and-it-doesnt-seem-to-be-listening-on-port-6969)
- [💻 Development](#-development)
  * [Building](#building)



# 🪄 Features
- 📦 Prepackaged images versioned by SPT version e.g. `fika-spt-server-docker:4.0.2` for SPT `4.0.2`. Images are hosted in ghcr and come prebuilt with a working SPT server binary, and the latest compatible Fika servermod is downloaded and installed on container startup if enabled.
- ♻️ Reuse an existing installation of SPT! Just mount your existing SPT server folder
- 💾 Automatic profile backups by default! Profiles are copied to a backup folder every day at 00:00 UTC
- 🔒 Configurable running user and ownership of server files. Control file ownership from the host, or let the container set ownership and permissions to ease permissions issues.
- ⬆️ Optionally auto updates SPT or Fika if we detect a version mismatch between container expected version and installed version
- ⬇️ Optionally auto download and install additional mods

# 🥡 Releases
The image build is triggered off release tags and hosted on ghcr
```
docker pull ghcr.io/zhliau/fika-spt-server-docker:4.0.2
```
Check the pane on the right for the different version tags available, if you don't want to use the latest SPT release.

# 🛫 Running
### docker
```
docker run --name fika-server \
  -e INSTALL_FIKA=true \
  -e LISTEN_ALL_NETWORKS=true \
  -v /path/to/server/files:/opt/server \
  -p 6969:6969 \
  ghcr.io/zhliau/fika-spt-server-docker:4.0.2
```

### docker-compose
See the example docker-compose for a more complete definition.

Minimal usage
```yaml
services:
  fika-server:
    image: ghcr.io/zhliau/fika-spt-server-docker:latest
    environment:
      - INSTALL_FIKA=true
      # This will automatically set SPT server's configs to work in a containerized environment
      - LISTEN_ALL_NETWORKS=true
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
      # ...
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
- If these existing server files were from a Windows installation, **delete** the `SPT.Server.exe` file to have the container use its own Linux-compiled binary
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
- Bring up the container again with `docker run` or `docker-compose up` (**NOT** `docker[-compose] restart` since this will not recreate the container)

The container will validate your Fika server mod version matches the image's expected version, and if not it will
- Back up the entire Fika server mod including configs to a `backups/fika` directory in the mounted server directory
- Install the expected fika server mod version
- Copy your old fika.jsonc config into the server mod config directory

> [!NOTE]
> The existing config is not guaranteed to work across versions. Expect to do some troubleshooting here especially if config options are added/removed in the new Fika server mod version.

### When SPT updates

> [!WARNING]
> If you've made any changes to files within `SPT_Data`, make backups! This upgrade process will remove that folder!

A new image will be tagged with the new SPT version number, and thus you will need to
- Update the image version tag e.g. `fika-spt-server-docker:3.9.8` to `fika-spt-server-docker:3.11.4`
- Pull the new image with `docker pull` or `docker-compose pull`
- Bring up the container again with `docker run` or `docker-compose up` (**NOT** `docker[-compose] restart` since this will not recreate the container)

The image will validate that your SPT version in the serverfiles matches the image's expected SPT version, and if not it will
- Back up the entire `user/` directory to a `backups/spt/` directory in the mounted server directory
- Remove the `SPT_Data` directory
- Install the right version of SPT in-place.

> [!NOTE]
> The user directory in your existing SPT server files is left untouched! Please make sure that you validate that the SPT version you are running works with your installed mods and profiles!
> You may want to start by removing all mods and validating them one by one

### (NEW for SPT 4.0+) Forcing SPT Versions
You can also force the install of a specific SPT version by supplying the `FORCE_SPT_VERSION` environment variable on container run. You must set this to a valid SPT release version, formatted as `<VERSION_NUMBER>-<EFT_BUILD_NUMBER>-<SPT_GIT_SHA>`. You can find an example of this in the SPT release archive name.

e.g
```
FORCE_SPT_VERSION=4.0.1-40087-1eacf0f
```

This will download the forced version release, and use that to update your server files.
This will disable the SPT auto-update feature, since you will be running your container out of sync with the expected image version.

## Automatically download & install additional mods
Instead of manually downloading and installing the other mods you want, you can have the server do it for you at boot!

> [!WARNING]
> Unlike with SPT and FIKA install features above, this feature does not check any versions, configs, etc. before overwriting. It basically just an automated system to download, extract, and then drag & drop mods into place, so use at your own risk.

### What it does
When the container starts, before it runs the SPT server executable, this will download the provided URLs, extract all the supported file types, and then do the following:
- Move the `BepInEx/plugins` and `user/mods` to their appropriate locations (effecitvely "installing" them, just like you'd do drag & drop in a local SPT install)
- Move any bare .dll files to BepInEx/plugins
- Move any .txt, .md. and .exe files to the root of the mounted directory.
  - Some mods are or come with .exe, like ModSync or SVM (ServerValueModifier)
  - .txt and .md are usually README's or licenses.
- Move any remaining downloaded/unzipped files to the `mods_download/remains` directory.

It also keeps track of each URL downloaded in the `mods_download/mod_urls_downloaded.txt` file so it does not re-download one that has already been downloaded unless you manually remove it from or delete that file entirely.

### How to use it
This is disabled by default so first the `INSTALL_OTHER_MODS` environment variable needs to be set to `true`.

There are two methods to specify the URLs: `mods_download/mod_urls_to_download.txt` and `MOD_URLS_TO_DOWNLOAD` environment variable. You can use either or both of these methods.

#### mod_urls_to_download.txt
Add the URLs to `mods_download/mod_urls_to_download.txt`. The file will be created automatically on the first run if the `INSTALL_OTHER_MODS` variable is set to `true`. Just make sure each URL is separated by a new line or space (or any mix of those if you're feeling chaotic neutral). Here's an example of what it could look like:

```
https://github.com/project-fika/Fika-Plugin/releases/download/v0.9.9015.15435/Fika.Release.0.9.9015.15435.zip
https://github.com/Solarint/SAIN/releases/download/v3.1.0-Release/SAIN-3.1.0-Release.7z https://github.com/DrakiaXYZ/SPT-BigBrain/releases/download/1.0.1/DrakiaXYZ-BigBrain-1.0.1.7z
https://github.com/DrakiaXYZ/SPT-Waypoints/releases/download/1.5.1/DrakiaXYZ-Waypoints-1.5.1.7z
https://github.com/Nympfonic/UnityToolkit/releases/download/v1.0.1/UnityToolkit-1.0.1.7z
https://github.com/Skwizzy/SPT-LootingBots/releases/download/v1.3.5-spt-3.9.0/Skwizzy-LootingBots-1.3.5.zip
https://github.com/dwesterwick/SPTQuestingBots/releases/download/0.7.0/DanW-SPTQuestingBots.zip https://github.com/mpstark/SPT-DynamicMaps/releases/download/0.3.4/DynamicMaps-0.3.4-b6d8bf85.zip

```
#### MOD_URLS_TO_DOWNLOAD Environment Variable

Just Set the environment variable `MOD_URLS_TO_DOWNLOAD` to a list of the URLs you want it to download. I don't think you can use new lines in environment variables, so just stick to spaces, but otherwise it would be the same as the `mod_urls_to_download.txt` example above.

> [!WARNING]
> If you use both methods, it may conflict if you download multiple versions of the same mod at the same time.

The URLs should point to a direct file download of a `.zip`, `.7z`, `.tar/.tar.gz`, or `.dll` file. It is assumed that compressed downloads (`.zip`, `.7z`, and `.tar/.tar.gz`) are already organized into the `BepInEx/plugins` and/or `user/mods` directory(ies). Most mod developers do this but not all of them. If a mod is not correctly organized then it will still be downloaded and extracted but the files will be moved to the `mods_download/remains` directory for you to handle manually.

If a mod requires any post-installation configuration, you will still need to do this manually.

A few other notes
* You can add or change the URLs whenever you want. Any new URLs will be downloaded and installed the next time the container is restarted.
* Removing a URL from the specified URLs does not remove the downloaded mod/files, it only stops it from checking that URL again.
* If you want to redownload the same url, you will need to manually remove it from `mods_download/mod_urls_downloaded.txt` file.

### Mod updates
When a mod is updated, you will need to add the new URL using one of the methods above. It will be downloaded, extracted, and then merged, overwriting any conflicting files in the installation. For simple mods that is probably enough. If the mod developer states that you will need to uninstall a previous version to update, you will have to do this manually. You may do that at any time if you want to be extra cautious.

## Time Zone
By default the container uses the UTC time zone. This does not affect running the server or the files themselves but it does affect things that like the SPT Backup Service, which sets the backup folder name to the current timestamp.

If you want to change the time zone there are two methods (DO NOT USE BOTH)
- Mount `/etc/timezone` as a volume
- Set the `TZ` environment variable

### Mount `/etc/timezone` as a volume
This will match the time zone inside to the time zone of the host system.
- If using docker-compose, add `/etc/timezone:/etc/timezone:ro` under the volumes section.
- If using docker run, add `-v /etc/timezone:/etc/timezone:ro \` to the run command

### Set the `TZ` environment variable
This should be set to a TZ Identifier (see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones for a list of valid TZ identifier).
- If using docker-compose, add `TZ=US/Eastern` under the `environment` section, substituting `US/Eastern` for your desired time zone.
- If using docker run, add `-e TZ=US/Eastern \` to the run command

# 🌐 Environment Variables
None of these env vars are required, but they may be useful.
| Env var                   | Default | Description                                                                                                                                                                                                                               |
| ------------------------- | ------- | -----------                                                                                                                                                                                                                               |
| `UID`                     | 1000    | The userID to use to run the server binary. This user is created in the container on runtime                                                                                                                                              |
| `GID`                     | 1000    | The groupID to assign when creating the user running the server binary. This has no effect if no UID is provided and no user is created                                                                                                   |
| `INSTALL_FIKA`            | false   | Whether you want the container to automatically install/update fika servermod for you                                                                                                                                                     |
| `INSTALL_OTHER_MODS`      | false   | Whether you want the container to automatically download & install any other mods as specified                                                                                                                                            |
| `MOD_URLS_TO_DOWNLOAD`    | null    | A space separated list of URLs you want the server to automatically download and place. Requires `INSTALL_OTHER_MODS` to be true                                                                                                          |
| `FIKA_VERSION`            | 1.0.4   | Override the fika version string to grab the server release from. The release URL is formatted as `https://github.com/project-fika/Fika-Server-CSharp/releases/download/$FIKA_VERSION/Fika.Server.Release.$FIKA_VERSION.zip`              |
| `AUTO_UPDATE_SPT`         | false   | Whether you want the container to handle updating SPT in your existing serverfiles                                                                                                                                                        |
| `AUTO_UPDATE_FIKA`        | false   | Whether you want the container to handle updating Fika server mod in your existing serverfiles                                                                                                                                            |
| `TAKE_OWNERSHIP`          | true    | If this is set to false, the container will not change file ownership of the server files. Make sure the running user has permissions to access these files                                                                               |
| `CHANGE_PERMISSIONS`      | true    | If this is set to false, the container will not change file permissions of the server files. Make sure the running user has permissions to access these files                                                                             |
| `ENABLE_PROFILE_BACKUP`   | true    | If this is set to false, the cron job that handles profile backups will not be enabled                                                                                                                                                    |
| `LISTEN_ALL_NETWORKS`     | false   | If you want to automatically set the SPT server IP addresses to allow it to listen on all network interfaces                                                                                                                              |
| `TZ`                      | null    | Set the desired time zone. See the `Timezone` section above for details                                                                                                                                                                   |
| `NUM_HEADLESS_PROFILES`   | null    | Set the desired number of headless profiles for the Fika server to auto-generate. This must be an integer. This will only work if the `fika.jsonc` config file exists, the server automatically generates one on startup if it is missing |
| `FORCE_SPT_VERSION`       | null    | Force a specific SPT version for this image. The version string should look like `SPT-<VERSION_NUMBER>-<EFT_BUILD_NUMBER>-<SPT_GIT_SHA>` e.g. `4.0.1-40087-1eacf0f`. You can see an example of this in the naming of the SPT release archive. |


# 💬 FAQ
### Why are there files owned by root in my server files?
If you don't want the root user to run SPT server, make sure you provide a userID/groupID to the image to use to run the server.
If none are provided, it defaults to uid 0 which is the root user.
Running the server with root will mean anything the server writes out is created by the root user.

### Can I use this without Fika?
Yes! Simply set `INSTALL_FIKA` to `false` and the container will act as an ordinary SPT server container. Everything else including the autoupdate capability for SPT remains unchanged.

### I am running this container on Linux, why does the server output show errors regarding Windows-like paths? e.g. `C:\snapshot\...`.
If you are reusing an existing SPT server that was previously running on Windows, you will need to delete the contents of your `/user/cache` folder.

### The server starts, but I cannot connect to it, and it doesn't seem to be listening on port 6969?
Set the environment variable `LISTEN_ALL_NETWORKS` to `true` and restart the container.

This will change the values of `ip` and `backendIp` in `SPT_Data/Server/configs/http.json` to `0.0.0.0`, which tells the SPT server to listen on all network interfaces. If you want to do this manually, the file should look similar to this:
```json
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

# 💻 Development
### Building
> [!WARNING]
> As of SPT version 4.0.0, these instructions are deprecated because we use precompiled server binaries
> In the future, I will implement building the server from source to support unreleased git tags

You can overwrite the expected SPT version by setting the `SPT_SHA` build arg. This must correspond with a git ref (tag or branch) in the
SPT Server github repo. This version must be a release [semver](https://semver.org/) value, or a pre-release ref like `3.11.4-dev`
The value is checked against the `sptVersion` value in `SPT_Data/Server/configs/core.json` when validating the SPT version on container boot. If using a pre-release version tag,
everything including and after the `-` is dropped when comparing version strings.

You can similarly override the Fika version by setting the `FIKA_VERSION` build arg. Make sure this matches the Fika version slug in the Fika Server download URL.

The URL will look like `https://github.com/project-fika/Fika-Server/releases/download/<FIKA_VERSION>/fika-server-<FIKA_VERSION_WITHOUT_V>.zip`

```bash
# Server binary built using SPT Server 3.11.4 git tag, image tagged as fika-spt-server:latest
# Downloads and validates Fika version v2.4.8

VERSION=latest FIKA_VERSION=v2.4.8 SPT_SHA=3.11.4 ./build
```
