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

echo "Extracting kernel and initramfs..."
mkdir -p "$BUILD_DIR"
docker cp "$CONTAINER_NAME:/boot/vmlinuz-virt" "$BUILD_DIR/bzImage"
docker cp "$CONTAINER_NAME:/initramfs.cpio.gz" "$BUILD_DIR/initramfs.cpio.gz"

echo "Cleaning up..."
docker rm "$CONTAINER_NAME" 2>/dev/null || true

INITRD_SIZE=$(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)
echo "Done. bzImage and initramfs.cpio.gz ($INITRD_SIZE) created in $BUILD_DIR/"
