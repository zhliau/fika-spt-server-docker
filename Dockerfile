FROM mcr.microsoft.com/dotnet/aspnet:9.0-bookworm-slim

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

ARG SPT_VERSION=4.0.2-40087-0df4ae7
ARG FIKA_VERSION=1.0.3
ENV SPT_VERSION=$SPT_VERSION
ENV FIKA_VERSION=$FIKA_VERSION

WORKDIR /opt/build
RUN curl -sL "https://spt-releases.modd.in/SPT-${SPT_VERSION}.7z" -o spt.7z
RUN 7zz x spt.7z

COPY entrypoint.sh /usr/bin/entrypoint
COPY scripts/backup.sh /usr/bin/backup
COPY scripts/download_unzip_install_mods.sh /usr/bin/download_unzip_install_mods
COPY data/cron/cron_backup_spt /etc/cron.d/cron_backup_spt

# Docker desktop doesn't allow you to configure port mappings unless this is present
EXPOSE 6969
ENTRYPOINT ["/usr/bin/entrypoint"]
