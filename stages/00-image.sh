#!/usr/bin/env bash
# Creates the image file, partitions it and mounts both partitions.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

BOOT_END_MB=1024
BOOT_START_MB=4

detach_loop() {
    [ -z "${device:-}" ] || losetup -d "$device" 2>/dev/null || true
}

log "creating ${IMAGE_SIZE_MB} MB image"
rm -f "$IMAGE"
dd if=/dev/zero of="$IMAGE" bs=1M count="$IMAGE_SIZE_MB" status=none

device="$(losetup -f)"
trap detach_loop EXIT
losetup -P "$device" "$IMAGE"

parted -s "$device" mklabel msdos
parted -s "$device" mkpart primary fat16 "${BOOT_START_MB}MB" "${BOOT_END_MB}MB"
parted -s "$device" mkpart primary ext4 "${BOOT_END_MB}MB" 100%
partprobe "$device" || true
sleep 2

[ -e "${device}p1" ] || die "boot partition device not created: ${device}p1"
[ -e "${device}p2" ] || die "root partition device not created: ${device}p2"

log "formatting partitions"
mkfs.vfat "${device}p1" >/dev/null
mkfs.ext4 -F -j "${device}p2" >/dev/null

losetup -d "$device"
trap - EXIT
device=""

# parted aligns partitions, so the real offsets are read back from the table.
mapfile -t starts < <(sfdisk -J "$IMAGE" | grep -oE '"start": *[0-9]+' | grep -oE '[0-9]+')
mapfile -t sizes < <(sfdisk -J "$IMAGE" | grep -oE '"size": *[0-9]+' | grep -oE '[0-9]+')
sector="$(sfdisk -J "$IMAGE" | grep -oE '"sectorsize": *[0-9]+' | grep -oE '[0-9]+')"

[ "${#starts[@]}" -eq 2 ] || die "expected 2 partitions, found ${#starts[@]}"
[ -n "$sector" ] || die "cannot read sector size"

boot_offset=$((starts[0] * sector))
boot_size=$((sizes[0] * sector))
root_offset=$((starts[1] * sector))
root_size=$((sizes[1] * sector))

log "mounting boot at offset $boot_offset, root at offset $root_offset"
mount -o "loop,offset=${boot_offset},sizelimit=${boot_size}" "$IMAGE" "$BOOT_DIR"
mount -o "loop,offset=${root_offset},sizelimit=${root_size}" "$IMAGE" "$ROOT_DIR"

mountpoint -q "$BOOT_DIR" || die "boot partition is not mounted"
mountpoint -q "$ROOT_DIR" || die "root partition is not mounted"
