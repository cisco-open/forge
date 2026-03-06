#!/bin/bash
set -x

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <download_path> <version>"
    exit 1
fi

DOWNLOAD_PATH="$1"
VERSION="$2"

if [ -n "$USE_CACHE" ] && [ -n "$CACHE_PATH" ] && [ -d "$CACHE_PATH" ]; then
    echo "USE_CACHE is set and $CACHE_PATH exists, skipping download." >&2
    DOWNLOAD_PATH="$CACHE_PATH"
    VERSION="local-cache"
else
    rm -rf "$DOWNLOAD_PATH"
    mkdir -p "$DOWNLOAD_PATH"

    # Download files to the specified directory
    wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/runner-binaries-syncer.zip"
    wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/runners.zip"
    wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/webhook.zip"
fi

echo -n "{\"version\":\"${VERSION}\",\"path\":\"${DOWNLOAD_PATH}\"}"
