#!/usr/bin/env bash
set -euo pipefail

CRON_FILE=/etc/cron.d/youtube-content-backup
CRON_SCHEDULE=${CRON_SCHEDULE:-"0 */2 * * *"}
CONFIG_FILE=${CONFIG_FILE:-/config/config.json}
DOWNLOAD_DIR=${DOWNLOAD_DIR:-/downloads}
LOG_DIR=${LOG_DIR:-/logs}
LOG_FILE=${LOG_DIR}/backup.log

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

{
  echo 'SHELL=/bin/bash'
  echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
  printf '%s root /usr/local/bin/backup.sh %s %s >> %s 2>&1\n' \
    "$CRON_SCHEDULE" \
    "$CONFIG_FILE" \
    "$DOWNLOAD_DIR" \
    "$LOG_FILE"
} > "$CRON_FILE"

chmod 0644 "$CRON_FILE"

{
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Startup run begin"
  if ! /usr/local/bin/backup.sh "$CONFIG_FILE" "$DOWNLOAD_DIR"; then
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Startup run failed; cron schedule will continue"
  fi
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] Startup run end"
} >> "$LOG_FILE" 2>&1

exec cron -f