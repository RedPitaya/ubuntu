#!/usr/bin/env bash
# Replaces the boot partition content of an image with an ecosystem archive.
# Usage: image-update.sh <image> <ecosystem.zip>

set -Eeuo pipefail

IMAGE="${1:?usage: image-update.sh <image> <ecosystem.zip>}"
ECOSYSTEM="${2:?usage: image-update.sh <image> <ecosystem.zip>}"
[ -f "$IMAGE" ] || { echo "image not found: $IMAGE" >&2; exit 1; }
[ -f "$ECOSYSTEM" ] || { echo "ecosystem archive not found: $ECOSYSTEM" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }

BOOT_DIR="$(mktemp -d)"
DEVICE="$(losetup -f)"

cleanup() {
    umount "$BOOT_DIR" 2>/dev/null || true
    losetup -d "$DEVICE" 2>/dev/null || true
    rmdir "$BOOT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

losetup -P "$DEVICE" "$IMAGE"
mkfs.vfat "${DEVICE}p1" >/dev/null
mount "${DEVICE}p1" "$BOOT_DIR"
unzip -o "$ECOSYSTEM" -d "$BOOT_DIR"
sync

echo "updated boot partition of $IMAGE"
