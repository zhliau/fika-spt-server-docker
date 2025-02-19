FROM debian:bookworm AS build

USER root
RUN apt update && apt install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    git-lfs

# asdf version manager
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
RUN ASDF_DIR=$HOME/.asdf/ \. "$HOME/.asdf/asdf.sh" \
    && asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git \
    && asdf install nodejs 20.11.1

WORKDIR /
RUN git clone https://github.com/sp-tarkov/server.git spt

# SPT Server git tag or sha
ARG SPT_SERVER_SHA=3.10.5
ARG BUILD_TYPE=release

WORKDIR /spt/project
RUN git checkout $SPT_SERVER_SHA
RUN git lfs pull

ENV PATH="$PATH:/root/.asdf/bin"
ENV PATH="$PATH:/root/.asdf/shims"
RUN asdf global nodejs 20.11.1

RUN npm install
RUN npm run build:$BUILD_TYPE

RUN mv build /opt/build
RUN rm -rf /spt

FROM debian:bookworm-slim
COPY --from=build /opt/build /opt/build

RUN apt update && apt install -y --no-install-recommends \
    curl \
    aria2 \
    ca-certificates \
    unzip \
    7zip \
    vim \
    cron \
    jq

WORKDIR /opt/server

ARG SPT_SERVER_SHA=3.10.5
ARG FIKA_VERSION=v2.3.6
ENV SPT_VERSION=$SPT_SERVER_SHA
ENV FIKA_VERSION=$FIKA_VERSION

COPY entrypoint.sh /usr/bin/entrypoint
COPY scripts/backup.sh /usr/bin/backup
COPY scripts/download_unzip_install_mods.sh /usr/bin/download_unzip_install_mods
COPY data/cron/cron_backup_spt /etc/cron.d/cron_backup_spt
ENTRYPOINT ["/usr/bin/entrypoint"]
