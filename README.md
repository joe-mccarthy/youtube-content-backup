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


