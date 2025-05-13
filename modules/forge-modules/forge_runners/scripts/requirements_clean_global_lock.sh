#!/bin/bash

TENANT_PATH="$1"

# Paths
LAMBDA_DIR="${PWD}/lambda"
PACKAGE_DIR="/${TENANT_PATH}/lambda_package/package"
LAMBDA_PACKAGE_DIR="/${TENANT_PATH}/lambda_package"

# Ensure the target directories exist
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

pip3 install -r "${LAMBDA_DIR}/requirements.txt" \
    --platform manylinux2014_x86_64 \
    --target="$PACKAGE_DIR" \
    --implementation cp \
    --python-version 3.11 \
    --only-binary=:all: --upgrade >/dev/null 2>&1

# Step 2: Copy the Python script to the package directory
cp "${LAMBDA_DIR}/github_clean_global_lock.py" "$LAMBDA_PACKAGE_DIR"

# Output the result in JSON format
echo "{\"status\": \"success\", \"message\": \"Dependencies installed successfully.\", \"lambda_package_dir\": \"$LAMBDA_PACKAGE_DIR\"}"
