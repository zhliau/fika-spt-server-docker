FROM debian:bookworm as build

# SPT Server git tag or sha
ARG SPT_SERVER_SHA=3.9.8

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
RUN git clone https://dev.sp-tarkov.com/SPT/Server.git spt

WORKDIR /spt/project
RUN git checkout $SPT_SERVER_SHA
RUN git lfs pull

ENV PATH="$PATH:/root/.asdf/bin"
ENV PATH="$PATH:/root/.asdf/shims"
RUN asdf global nodejs 20.11.1

RUN npm install
RUN npm run build:release

RUN mv build /opt/build
RUN rm -rf /spt

FROM debian:bookworm-slim
COPY --from=build /opt/build /opt/build

RUN apt update && apt install -y --no-install-recommends \
    curl \
    ca-certificates \
    unzip \
    vim \
    cron \
    jq

WORKDIR /opt/server

COPY entrypoint.sh /usr/bin/entrypoint
COPY backup.sh /usr/bin/backup
COPY cron_backup_spt /etc/cron.d/cron_backup_spt
ENTRYPOINT ["/usr/bin/entrypoint"]
