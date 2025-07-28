#!/bin/bash
set -x

if [ -z "$1" ]; then
    echo "Usage: $0 <download_path>"
    exit 1
fi

DOWNLOAD_PATH="$1"
# renovate: datasource=github-tags depName=github-aws-runners/terraform-aws-github-runner registryUrl=https://github.com/
VERSION="6.7.2"

rm -rf "$DOWNLOAD_PATH"
mkdir -p "$DOWNLOAD_PATH"

# Download files to the specified directory
wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/v${VERSION}/runner-binaries-syncer.zip"
wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/v${VERSION}/runners.zip"
wget --no-verbose -P "$DOWNLOAD_PATH" "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/v${VERSION}/webhook.zip"

echo -n "{\"version\":\"${VERSION}\"}"
