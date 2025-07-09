#!/bin/bash
set -euo pipefail

# ────────────── VARIABLES ──────────────
LAMBDA_PATH="$1"
LAMBDA_DIR="${PWD}/lambda"
PACKAGE_DIR="${LAMBDA_PATH}/lambda_package/package"
LAMBDA_PACKAGE_DIR="${LAMBDA_PATH}/lambda_package"
ZIP_PATH="${LAMBDA_PACKAGE_DIR}/lambda.zip"
REQUIREMENTS_FILE="${LAMBDA_DIR}/requirements.txt"
HANDLER_FILE="${LAMBDA_DIR}/${2}.py"
COMMON_FILE="${LAMBDA_DIR}/common.py"

# ────────────── PRECHECKS ──────────────
if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
    echo "{\"status\": \"error\", \"message\": \"Missing requirements.txt in $LAMBDA_DIR\"}"
    exit 1
fi

if [[ ! -f "$HANDLER_FILE" ]]; then
    echo "{\"status\": \"error\", \"message\": \"Missing ${2}.py in $LAMBDA_DIR\"}"
    exit 1
fi

# ────────────── CLEAN & SETUP ──────────────
rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"

# ────────────── INSTALL DEPENDENCIES ──────────────
pip3 install -r "$REQUIREMENTS_FILE" \
    --platform manylinux2014_x86_64 \
    --target="$PACKAGE_DIR" \
    --implementation cp \
    --python-version 3.11 \
    --only-binary=:all: \
    --upgrade \
    --no-cache-dir >/dev/null

# ────────────── CLEAN JUNK FILES ──────────────
find "$PACKAGE_DIR" -name "*.dist-info" -exec rm -rf {} +
find "$PACKAGE_DIR" -name "*.egg-info" -exec rm -rf {} +
find "$PACKAGE_DIR" -name "__pycache__" -exec rm -rf {} +
find "$PACKAGE_DIR" -name "tests" -type d -exec rm -rf {} +
find "$PACKAGE_DIR" -name "test" -type d -exec rm -rf {} +

# ────────────── CREATE ZIP ──────────────
cd "$PACKAGE_DIR"
zip -r9 "$ZIP_PATH" . >/dev/null

cd "$LAMBDA_PACKAGE_DIR"
cp "$HANDLER_FILE" .
cp "$COMMON_FILE" .
zip -g "$ZIP_PATH" "${2}.py" >/dev/null
zip -g "$ZIP_PATH" "common.py" >/dev/null

# ────────────── DONE ──────────────
echo "{\"status\": \"success\", \"zip_path\": \"$ZIP_PATH\"}"
