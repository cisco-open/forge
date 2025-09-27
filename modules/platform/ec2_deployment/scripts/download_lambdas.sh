#!/bin/bash
set -x

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <download_path> <version>"
    exit 1
fi

DOWNLOAD_PATH="$1"
VERSION="$2"

rm -rf "$DOWNLOAD_PATH"
mkdir -p "$DOWNLOAD_PATH"

# Download files to the specified director
wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/runner-binaries-syncer.zip"
wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/runners.zip"
wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/webhook.zip"

echo -n "{\"version\":\"${VERSION}\"}"
