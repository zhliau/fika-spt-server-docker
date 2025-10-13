FROM debian:bookworm-slim

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
# Temporarily add package repo manually since GHA runners can't seem to pull it
COPY data/packages-microsoft-prod.deb /
#RUN curl -L  https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
#RUN rm packages-microsoft-prod.deb
RUN apt search aspnetcore
RUN apt update && apt install -y aspnetcore-runtime-9.0

ARG SPT_RELEASE_VERSION=4.0.0-40087-0582f8d

WORKDIR /opt/build
RUN curl -sL "https://spt-releases.modd.in/SPT-${SPT_RELEASE_VERSION}.7z" -o spt.7z
RUN 7zz x spt.7z

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
