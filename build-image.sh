#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="ghcr.io/joe-mccarthy/youtube-content-backup:latest"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "Building image: $IMAGE_TAG"
docker build -t "$IMAGE_TAG" "$SCRIPT_DIR"

echo "Build complete: $IMAGE_TAG"