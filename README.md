# Content Backup

Simple bash script that takes a list of either YouTube channels or playlists downloads the content then converts them to mp3.

**This is a back up tool for your own content or content that you have permission to download**

## Back Up
- Entire Channel with just the channel url
- Append /videos to channel name to avoid shorts
- Accepts playlist URLS

## Features
- Embeds the video thumbnail into the mp3 file
- Creates /covers in each download location to save thumbnails
- Keeps track of what has been downloaded to avoid duplication
- Ensure that a single instance of the back up is running

## Required Packages
- yt-dlp 
- ffmpeg 
- jq 
- curl
- flock

## Docker
Build the image:

```bash
docker build -t youtube-content-backup .
```

Run it with a mounted config file and a separate download directory:

```bash
docker run -d \
	--name youtube-content-backup \
	-e CONFIG_FILE="/config/config.json" \
	-e DOWNLOAD_DIR="/downloads" \
	-e LOG_DIR="/logs" \
	-e YTDLP_JS_RUNTIMES="node" \
	-e YTDLP_COOKIES_FILE="/config/cookies.txt" \
	-v "$PWD/config.json:/config/config.json" \
	-v "$PWD/cookies.txt:/config/cookies.txt:ro" \
	-v "$PWD/downloads:/downloads" \
	-v "$PWD/logs:/logs" \
	youtube-content-backup
```

The container default schedule is every 2 hours (`0 */2 * * *`). Set `CRON_SCHEDULE` to override it. The container runs `backup.sh` with the config file path from `CONFIG_FILE` and writes downloads to `DOWNLOAD_DIR`. Cron output is written to `LOG_DIR/backup.log`.

If YouTube requests return `HTTP Error 403: Forbidden`, export browser cookies to `cookies.txt`, mount it, and set `YTDLP_COOKIES_FILE` as shown above.

If you see `challenge solving failed` warnings, ensure `YTDLP_JS_RUNTIMES` is set (defaults to `node` in this project). You can optionally set `YTDLP_REMOTE_COMPONENTS` (for example `ejs:github`) for runtime EJS component downloads.

`Another instance is running, exiting.` is expected when `CRON_SCHEDULE` triggers a new run before the previous run finishes. The lock prevents overlapping downloads.

On container startup, `backup.sh` runs once immediately, then cron continues on the configured schedule.

## Docker Compose
Example `docker-compose.yml`:

```yaml
services:
	youtube-content-backup:
		build: .
		container_name: youtube-content-backup
		restart: unless-stopped
		environment:
			CRON_SCHEDULE: "0 */2 * * *"
			CONFIG_FILE: /config/config.json
			DOWNLOAD_DIR: /downloads
			LOG_DIR: /logs
			YTDLP_JS_RUNTIMES: node
			YTDLP_COOKIES_FILE: /config/cookies.txt
		volumes:
			- ./config.json:/config/config.json:ro
			- ./cookies.txt:/config/cookies.txt:ro
			- ./downloads:/downloads
			- ./logs:/logs
```

Start it with:

```bash
docker compose up -d
```

## Automatic Releases
Pushes to `main` trigger the GitHub Actions release workflow. It automatically creates a new git tag, GitHub Release, and GHCR image for the next version.

Version bumps are inferred from the commits since the last tag:

- `major` if a commit includes a breaking change marker, such as `!:` in the subject or `BREAKING CHANGE:` in the body
- `minor` if a commit uses a `feat` commit message
- `patch` for everything else

The release workflow tags the repository with the computed version and publishes the Docker image with the same version tag, plus `latest`.


