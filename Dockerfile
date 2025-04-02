FROM debian:bookworm AS build

USER root
RUN apt update && apt install -y --no-install-recommends \
    aria2 \
    curl \
    ca-certificates \
    libicu-dev \
    git \
    git-lfs \
    unzip \
    7zip \
    vim \
    cron \
    jq

# asdf version manager
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1

ARG DOTNET_VERSION=9.0.202
RUN ASDF_DIR=$HOME/.asdf/ \. "$HOME/.asdf/asdf.sh" \
    && asdf plugin add dotnet https://github.com/hensou/asdf-dotnet.git \
    && asdf install dotnet $DOTNET_VERSION

WORKDIR /
# SPT Server git tag or sha
ARG SPT_SERVER_SHA=4.0.0-buildtest
ARG BUILD_TYPE=Release

RUN git clone https://github.com/sp-tarkov/server-csharp.git spt

WORKDIR /spt
RUN git checkout $SPT_SERVER_SHA
RUN git lfs pull

ENV PATH="$PATH:/root/.asdf/bin"
ENV PATH="$PATH:/root/.asdf/shims"
RUN asdf global dotnet $DOTNET_VERSION
RUN asdf current

# cribbed from .asdf/plugins/dotnet/set-dotnet-env.bash
ENV DOTNET_ROOT=/root/.asdf/installs/dotnet/$DOTNET_VERSION
ENV DOTNET_VERSION=$DOTNET_VERSION
ENV MSBuildSDKsPath=$DOTNET_ROOT/sdk/$DOTNET_VERSION/Sdks
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

RUN dotnet build --configuration=Release

RUN cp -r SPTarkov.Server/bin/Release/net9.0 /opt/build
RUN rm -rf /spt

WORKDIR /opt/server

ARG SPT_SERVER_SHA=4.0.0-buildtest
ARG FIKA_VERSION=v2.4.4
ENV SPT_VERSION=$SPT_SERVER_SHA
ENV FIKA_VERSION=$FIKA_VERSION

COPY entrypoint.sh /usr/bin/entrypoint
COPY scripts/backup.sh /usr/bin/backup
COPY scripts/download_unzip_install_mods.sh /usr/bin/download_unzip_install_mods
COPY data/cron/cron_backup_spt /etc/cron.d/cron_backup_spt
ENTRYPOINT ["/usr/bin/entrypoint"]
