FROM mcr.microsoft.com/dotnet/aspnet:10.0

RUN apt update && apt install -y --no-install-recommends \
    curl \
    aria2 \
    ca-certificates \
    unzip \
    7zip \
    vim \
    cron \
    exiftool \
    jq \
    dos2unix

ARG SPT_VERSION=4.1.6-40743-731d7a2
ARG FIKA_VERSION=2.4.2
ARG SPT_RELEASE_URL=https://mirror.sp-tushonka.com/builds
ENV SPT_VERSION=$SPT_VERSION
ENV FIKA_VERSION=$FIKA_VERSION
ENV SPT_RELEASE_URL=$SPT_RELEASE_URL

WORKDIR /opt/build
RUN curl -fsSL "${SPT_RELEASE_URL}/SPT-${SPT_VERSION}.7z" -o spt.7z
RUN command -v 7zz || ln -s "$(command -v 7z || command -v 7za || command -v 7zr)" /usr/local/bin/7zz
RUN 7zz x spt.7z

COPY entrypoint.sh /usr/bin/entrypoint
COPY scripts/backup.sh /usr/bin/backup
COPY scripts/download_unzip_install_mods.sh /usr/bin/download_unzip_install_mods
COPY data/cron/cron_backup_spt /etc/cron.d/cron_backup_spt
RUN dos2unix /usr/bin/entrypoint /usr/bin/backup /usr/bin/download_unzip_install_mods /etc/cron.d/cron_backup_spt && \
    chmod +x /usr/bin/entrypoint /usr/bin/backup /usr/bin/download_unzip_install_mods /etc/cron.d/cron_backup_spt

# Docker desktop doesn't allow you to configure port mappings unless this is present
EXPOSE 6969
ENTRYPOINT ["/usr/bin/entrypoint"]
