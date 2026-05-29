#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="build"
CONTAINER_NAME="alpine-cli"
IMAGE_NAME="alpine-cli"

echo "Building Alpine rootfs..."
docker build . --platform linux/386 --rm --tag "$IMAGE_NAME"

echo "Creating container..."
docker rm "$CONTAINER_NAME" 2>/dev/null || true
docker create --platform linux/386 -t -i --name "$CONTAINER_NAME" "$IMAGE_NAME"

echo "Extracting boot files..."
mkdir -p "$BUILD_DIR"
docker cp "$CONTAINER_NAME:/output/vmlinuz" "$BUILD_DIR/vmlinuz"
docker cp "$CONTAINER_NAME:/output/initrd.img" "$BUILD_DIR/initrd.img"
docker cp "$CONTAINER_NAME:/output/disk.img" "$BUILD_DIR/disk.img"

echo "Cleaning up..."
docker rm "$CONTAINER_NAME" 2>/dev/null || true

KERNEL_SIZE=$(du -h "$BUILD_DIR/vmlinuz" | cut -f1)
INITRD_SIZE=$(du -h "$BUILD_DIR/initrd.img" | cut -f1)
DISK_SIZE=$(du -h "$BUILD_DIR/disk.img" | cut -f1)
echo "Done. vmlinuz ($KERNEL_SIZE) + initrd ($INITRD_SIZE) + disk.img ($DISK_SIZE) in $BUILD_DIR/"
