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

echo "Creating initramfs inside Docker..."
BUILDER_IMAGE="alpine-cli-initramfs"
cat <<'DOCKERFILE' | docker build --platform linux/386 -t "$BUILDER_IMAGE" -
FROM docker.io/i386/alpine:3.21.0
RUN apk add cpio gzip
DOCKERFILE

docker rm "${CONTAINER_NAME}-builder" 2>/dev/null || true
docker create --platform linux/386 -t -i --name "${CONTAINER_NAME}-builder" \
  -v "$(pwd)/${BUILD_DIR}":/output \
  "$BUILDER_IMAGE" \
  sh -c 'mkdir -p /rootfs && tar xf /output/alpine-rootfs.tar -C /rootfs && cp /rootfs/boot/vmlinuz-virt /output/bzImage && cd /rootfs && find . -print0 | cpio -o -0 -H newc --quiet | gzip -9 > /output/initramfs.cpio.gz && rm -rf /rootfs'

docker start --attach "${CONTAINER_NAME}-builder"

echo "Cleaning up..."
rm -f "$BUILD_DIR/alpine-rootfs.tar"
docker rm "${CONTAINER_NAME}-builder" 2>/dev/null || true
docker rmi "$BUILDER_IMAGE" 2>/dev/null || true

INITRD_SIZE=$(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)
echo "Done. bzImage and initramfs.cpio.gz ($INITRD_SIZE) created in $BUILD_DIR/"
