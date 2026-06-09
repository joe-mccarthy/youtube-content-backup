#!/usr/bin/env bash
set -euo pipefail

# Cron can run with a minimal PATH; ensure commonly used install prefixes are included.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <config-file> <download-dir>" >&2
  exit 1
fi

CONFIG_FILE="$1"
DOWNLOAD_DIR="$2"

COOKIES_FILE="${YTDLP_COOKIES_FILE:-}"
YTDLP_EXTRACTOR_ARGS="${YTDLP_EXTRACTOR_ARGS:-youtube:player_client=web,web_safari}"
YTDLP_JS_RUNTIMES="${YTDLP_JS_RUNTIMES:-node}"
YTDLP_REMOTE_COMPONENTS="${YTDLP_REMOTE_COMPONENTS:-ejs:github}"

echo "config location: $CONFIG_FILE"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

for cmd in jq yt-dlp flock ffmpeg; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

mkdir -p "$DOWNLOAD_DIR"

CONFIG_FILE="$(realpath "$CONFIG_FILE")"
DOWNLOAD_DIR="$(realpath "$DOWNLOAD_DIR")"
LOCK_FILE="$DOWNLOAD_DIR/yt-channel-to-mp3.lock"

# Prevent overlapping runs
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another instance is running, exiting."
  exit 0
fi

jq -c '.channels[]' "$CONFIG_FILE" | while IFS= read -r CH; do
  CREATOR="$(jq -r '.creator' <<<"$CH")"
  CHANNEL_URL="$(jq -r '.url' <<<"$CH")"

  if [[ -z "$CREATOR" || "$CREATOR" == "null" || \
        -z "$CHANNEL_URL" || "$CHANNEL_URL" == "null" ]]; then
    echo "Skipping invalid channel entry: $CH" >&2
    continue
  fi

  # Safe directory name from creator string
  SAFE_CREATOR="$(
    echo "$CREATOR" \
      | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^a-z0-9._-]/_/g'
  )"

  CHANNEL_DIR="$DOWNLOAD_DIR/$SAFE_CREATOR"
  ARCHIVE_FILE="$CHANNEL_DIR/.yt-archive.txt"

  mkdir -p "$CHANNEL_DIR/covers"

  echo ">>> Channel: $CREATOR"
  echo ">>> URL:     $CHANNEL_URL"
  echo ">>> Dir:     $CHANNEL_DIR"

  YTDLP_ARGS=(
    --force-ipv4

    # Useful output without being too noisy
    --no-progress

    # Continue through bad/private/deleted/unavailable videos
    -i
    --skip-playlist-after-errors 5

    # Audio extraction
    -x
    --audio-format mp3
    --audio-quality 5
    --format "bestaudio/best"

    # Reliability
    --retries 10
    --fragment-retries 10
    --retry-sleep 5
    --sleep-interval 10

    # Playlist/channel behaviour
    --yes-playlist
    --download-archive "$ARCHIVE_FILE"

    # Filenames
    --restrict-filenames
    --trim-filenames 120

    # Main audio output
    -o "$CHANNEL_DIR/%(upload_date>%Y-%m-%d)s - %(title).100B [%(id)s].%(ext)s"

    # Thumbnails
    --write-thumbnail
    --convert-thumbnails jpg
    --embed-thumbnail
    -o "thumbnail:$CHANNEL_DIR/covers/%(upload_date>%Y-%m-%d)s - %(title).100B [%(id)s].%(ext)s"

    # Log each successful download
    --exec 'f="{}"; f="${f##*/}"; echo "Downloaded: $f"'
  )

  if [[ -n "$COOKIES_FILE" ]]; then
    if [[ -f "$COOKIES_FILE" ]]; then
      YTDLP_ARGS+=(--cookies "$COOKIES_FILE")
    else
      echo "WARNING: Cookies file set but not found: $COOKIES_FILE" >&2
    fi
  fi

  # Optional manual override for YouTube extractor args.
  #
  # Examples:
  #   YTDLP_EXTRACTOR_ARGS='youtube:player_client=default'
  #   YTDLP_EXTRACTOR_ARGS='youtube:player_client=web,default'
  #
  # Leave unset unless you need to test around a YouTube issue.
  if [[ -n "$YTDLP_EXTRACTOR_ARGS" ]]; then
    YTDLP_ARGS+=(--extractor-args "$YTDLP_EXTRACTOR_ARGS")
  fi

  if [[ -n "$YTDLP_JS_RUNTIMES" ]]; then
    YTDLP_ARGS+=(--js-runtimes "$YTDLP_JS_RUNTIMES")
  fi

  if [[ -n "$YTDLP_REMOTE_COMPONENTS" ]]; then
    YTDLP_ARGS+=(--remote-components "$YTDLP_REMOTE_COMPONENTS")
  fi

  if ! yt-dlp "${YTDLP_ARGS[@]}" "$CHANNEL_URL"; then
    echo "WARNING: yt-dlp failed for $CREATOR, continuing." >&2
    echo
    continue
  fi

  echo ">>> Done: $CREATOR"
  echo
done