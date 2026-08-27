#!/usr/bin/env bash
# Cleans the rootfs, removes ARM emulation and creates the rootfs tarball.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

log "cleaning package caches"
chroot_run <<'EOF'
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/* /var/tmp/*
rm -rf /root/.cache /home/jupyter/.cache
EOF

unmount_pseudo

rm -f "$ROOT_DIR/usr/bin/qemu-arm-static"

# The tarball must not contain resolv.conf, it breaks schroot based tooling.
rm -f "$ROOT_DIR/etc/resolv.conf"

log "zero filling free space"
cat /dev/zero > "$ROOT_DIR/zero.file" || true
sync -f "$ROOT_DIR/zero.file" || true
rm -f "$ROOT_DIR/zero.file"

log "creating rootfs tarball"
tar -cpzf "$OUT_DIR/${IMAGE_NAME}.tar.gz" --one-file-system -C "$ROOT_DIR" .

ln -sf /run/systemd/resolve/resolv.conf "$ROOT_DIR/etc/resolv.conf"
sync
