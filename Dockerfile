#FROM debian:bookworm AS build

#USER root
#RUN apt update && apt install -y --no-install-recommends \
#    aria2 \
#    curl \
#    ca-certificates \
#    libicu-dev \
#    git \
#    git-lfs \
#    unzip \
#    7zip \
#    vim \
#    cron \
#    xmlstarlet \
#    jq
#
## SPT Server git tag or sha
#ARG SPT_SERVER_SHA=4.0.0-buildtest
#ARG BUILD_TYPE=Release
#ARG DOTNET_VERSION=9.0.202
#ARG RUNTIME_IDENTIFIER=linux-x64
#
## asdf version manager
#RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
#
#RUN ASDF_DIR=$HOME/.asdf/ \. "$HOME/.asdf/asdf.sh" \
#    && asdf plugin add dotnet https://github.com/hensou/asdf-dotnet.git \
#    && asdf install dotnet $DOTNET_VERSION
#
#WORKDIR /
#
#RUN git clone https://github.com/sp-tarkov/server-csharp.git spt
#
#WORKDIR /spt
#RUN git checkout $SPT_SERVER_SHA
#RUN git lfs pull
#
#ENV PATH="$PATH:/root/.asdf/bin"
#ENV PATH="$PATH:/root/.asdf/shims"
#RUN asdf global dotnet $DOTNET_VERSION
#RUN asdf current
#
## Cribbed from .asdf/plugins/dotnet/set-dotnet-env.bash
#ENV DOTNET_ROOT=/root/.asdf/installs/dotnet/$DOTNET_VERSION
#ENV DOTNET_VERSION=$DOTNET_VERSION
#ENV MSBuildSDKsPath=$DOTNET_ROOT/sdk/$DOTNET_VERSION/Sdks
#ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

## Add runtime identifier to build self-contained binary
## This is because the running user is not necessarily root,
## and will not have access to the dotnet framework installed by asdf
#RUN xmlstarlet ed -L -s /Project/PropertyGroup -t elem -n "RuntimeIdentifier" -v "$RUNTIME_IDENTIFIER" Build.props
#RUN dotnet build --configuration=$BUILD_TYPE --sc
#RUN dotnet publish --configuration=$BUILD_TYPE --sc

#RUN cp -r SPTarkov.Server/bin/Release/net9.0/$RUNTIME_IDENTIFIER /opt/build
#RUN rm -rf /spt

FROM debian:bookworm-slim

#COPY --from=build /opt/build /opt/build
RUN apt update && apt install -y --no-install-recommends \
    curl \
    aria2 \
    ca-certificates \
    unzip \
    7zip \
    vim \
    cron \
    exiftool \
    jq

# Runtime dependencies
RUN curl -L  https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN rm packages-microsoft-prod.deb
RUN apt update && apt install -y aspnetcore-runtime-9.0

ARG SPT_RELEASE_VERSION=4.0.0-40087-0582f8d

WORKDIR /opt/build
RUN curl -sL "https://spt-releases.modd.in/SPT-${SPT_RELEASE_VERSION}.7z" -o spt.7z
RUN ls -la
RUN 7zz x spt.7z
RUN ls -la

ARG FIKA_VERSION=1.0.0
ENV SPT_VERSION=$SPT_RELEASE_VERSION
ENV FIKA_VERSION=$FIKA_VERSION

COPY entrypoint.sh /usr/bin/entrypoint
COPY scripts/backup.sh /usr/bin/backup
COPY scripts/download_unzip_install_mods.sh /usr/bin/download_unzip_install_mods
COPY data/cron/cron_backup_spt /etc/cron.d/cron_backup_spt

# Docker desktop doesn't allow you to configure port mappings unless this is present
EXPOSE 6969
ENTRYPOINT ["/usr/bin/entrypoint"]
