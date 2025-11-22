#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$1/config.json"
LOCK_FILE="$1/yt-channel-to-mp3.lock"

echo "config location: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Prevent overlapping runs
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another instance is running, exiting."
  exit 0
fi

BASE_DIR=$(jq -r '.base_dir' "$CONFIG_FILE")

if [ -z "$BASE_DIR" ] || [ "$BASE_DIR" = "null" ]; then
  echo "Missing base_dir in JSON config" >&2
  exit 1
fi

mkdir -p "$BASE_DIR"

jq -c '.channels[]' "$CONFIG_FILE" | while IFS= read -r CH; do
  CREATOR=$(jq -r '.creator' <<<"$CH")
  CHANNEL_URL=$(jq -r '.url' <<<"$CH")

  if [ -z "$CREATOR" ] || [ "$CREATOR" = "null" ] || \
     [ -z "$CHANNEL_URL" ] || [ "$CHANNEL_URL" = "null" ]; then
    echo "Skipping invalid channel entry: $CH" >&2
    continue
  fi

  # Safe directory name from creator string
  SAFE_CREATOR=$(echo "$CREATOR" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9._-]/_/g')

  DOWNLOAD_DIR="$BASE_DIR/$SAFE_CREATOR"
  mkdir -p "$DOWNLOAD_DIR/covers"
  cd "$DOWNLOAD_DIR"

  ARCHIVE_FILE=".yt-archive.txt"

  echo ">>> Channel: $CREATOR"
  echo ">>> URL:     $CHANNEL_URL"

  yt-dlp \
    --force-ipv4 \
    -q --no-warnings --no-progress \
    -i \
    -x --audio-format mp3 --audio-quality 5 \
    --yes-playlist \
    --download-archive "$ARCHIVE_FILE" \
    --restrict-filenames \
    --trim-filenames 120 \
    --write-thumbnail \
    --embed-thumbnail \
    --sleep-interval 10 \
    --convert-thumbnails jpg \
    -o "%(title)s.%(ext)s" \
    -o "thumbnail:covers/%(title)s.%(ext)s" \
    --exec 'f="{}"; f="${f##*/}"; echo "Downloaded: $f"' \
    "$CHANNEL_URL"

  echo ">>> Done: $CREATOR"
  echo
done
