FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    CRON_SCHEDULE="0 */2 * * *" \
    CONFIG_FILE="/config/config.json" \
    DOWNLOAD_DIR="/downloads" \
    LOG_DIR="/logs"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        cron \
        curl \
        ffmpeg \
        jq \
        util-linux \
        ca-certificates \
        gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir --upgrade "yt-dlp[default]"

WORKDIR /app

COPY backup.sh /usr/local/bin/backup.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/docker-entrypoint.sh

VOLUME ["/config", "/downloads", "/logs"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]