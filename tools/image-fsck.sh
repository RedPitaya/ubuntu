#!/usr/bin/env bash
# Read only file system check of both partitions of an image.
# Usage: image-fsck.sh <image>

set -Eeuo pipefail

IMAGE="${1:?usage: image-fsck.sh <image>}"
[ -f "$IMAGE" ] || { echo "image not found: $IMAGE" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }

DEVICE="$(losetup -f)"
trap 'losetup -d "$DEVICE" 2>/dev/null || true' EXIT

losetup -P "$DEVICE" "$IMAGE"

rc=0
fsck.vfat -n "${DEVICE}p1" || rc=$?
fsck.ext4 -nf "${DEVICE}p2" || rc=$?

exit "$rc"
