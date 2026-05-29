#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="build"
CONTAINER_NAME="alpine-cli"
IMAGE_NAME="alpine-cli"

echo "Building Alpine rootfs..."
docker build . --platform linux/386 --rm --tag "$IMAGE_NAME"

echo "Exporting filesystem..."
docker rm "$CONTAINER_NAME" 2>/dev/null || true
docker create --platform linux/386 -t -i --name "$CONTAINER_NAME" "$IMAGE_NAME"

ROOTFS_TAR="$BUILD_DIR/alpine-rootfs.tar"
docker export "$CONTAINER_NAME" -o "$ROOTFS_TAR"

tar -f "$ROOTFS_TAR" --delete ".dockerenv" 2>/dev/null || true

echo "Generating filesystem metadata..."
python3 "$BUILD_DIR/fs2json.py" --out "$BUILD_DIR/alpine-fs.json" "$ROOTFS_TAR"

echo "Creating flat content-addressed files..."
mkdir -p "$BUILD_DIR/alpine-rootfs-flat"
python3 "$BUILD_DIR/copy-to-sha256.py" "$ROOTFS_TAR" "$BUILD_DIR/alpine-rootfs-flat"

echo "Done. rootfs, alpine-rootfs-flat/ and alpine-fs.json created in $BUILD_DIR/"
