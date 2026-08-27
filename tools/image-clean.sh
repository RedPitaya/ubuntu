#!/usr/bin/env bash
# Recreates the FAT partition and clears host metadata, SSH keys and free
# space of an existing image, so it compresses well.
# Usage: image-clean.sh <image>

set -Eeuo pipefail

IMAGE="${1:?usage: image-clean.sh <image>}"
[ -f "$IMAGE" ] || { echo "image not found: $IMAGE" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }

BOOT_DIR="$(mktemp -d)"
ROOT_DIR="$(mktemp -d)"
DEVICE="$(losetup -f)"

cleanup() {
    umount "$BOOT_DIR" 2>/dev/null || true
    umount "$ROOT_DIR" 2>/dev/null || true
    losetup -d "$DEVICE" 2>/dev/null || true
    rmdir "$BOOT_DIR" "$ROOT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

losetup -P "$DEVICE" "$IMAGE"
mkfs.vfat "${DEVICE}p1" >/dev/null
mount "${DEVICE}p1" "$BOOT_DIR"
mount "${DEVICE}p2" "$ROOT_DIR"

rm -rf "$BOOT_DIR/.Spotlight-V100" "$BOOT_DIR/.Trashes" "$BOOT_DIR/System Volume Information"
rm -f "$ROOT_DIR"/etc/ssh/ssh_host_*

cat /dev/zero > "$ROOT_DIR/zero.file" || true
sync -f "$ROOT_DIR/zero.file"
rm -f "$ROOT_DIR/zero.file"

echo "cleaned $IMAGE"
