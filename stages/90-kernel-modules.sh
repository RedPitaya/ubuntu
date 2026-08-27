#!/usr/bin/env bash
# Builds the Red Pitaya kernel modules inside the target rootfs and installs
# the wireless firmware.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

copy_overlay_dir lib/firmware

if [ "$BUILD_KERNEL_MODULES" != "1" ]; then
    log "kernel module build skipped (BUILD_KERNEL_MODULES=$BUILD_KERNEL_MODULES)"
    exit 0
fi

MAKE_ARGS="ARCH=arm CROSS_COMPILE=$KERNEL_CROSS_COMPILE"

log "preparing kernel source ($KERNEL_BRANCH)"
chroot_run <<EOF
apt-get install -y kmod
rm -rf /tmp/kernel
git clone --depth 1 --branch $KERNEL_BRANCH $KERNEL_URL /tmp/kernel
git -C /tmp/kernel rev-parse HEAD > /tmp/kernel_commit
rm -rf /tmp/kernel/.git /tmp/kernel/.github
make -C /tmp/kernel $MAKE_ARGS mrproper
touch /tmp/kernel/.scmversion
make -C /tmp/kernel $MAKE_ARGS $KERNEL_DEFCONFIG
make -s -C /tmp/kernel $MAKE_ARGS kernelrelease > /tmp/kernel_release
EOF

KERNEL_RELEASE="$(cat "$ROOT_DIR/tmp/kernel_release")"
[ -n "$KERNEL_RELEASE" ] || die "cannot determine kernel release"

log "building modules for $KERNEL_RELEASE"
chroot_run <<EOF
make -C /tmp/kernel $MAKE_ARGS KCFLAGS="$KERNEL_KCFLAGS" -j$(nproc) modules
make -C /tmp/kernel $MAKE_ARGS INSTALL_MOD_PATH= modules_install
depmod -a $KERNEL_RELEASE
rm -rf /tmp/kernel
EOF

MODULE_DIR="$ROOT_DIR/lib/modules/$KERNEL_RELEASE"
[ -d "$MODULE_DIR" ] || die "modules were not installed into /lib/modules/$KERNEL_RELEASE"
[ -f "$MODULE_DIR/modules.dep" ] || die "depmod did not create modules.dep"

MODULE_COUNT="$(find "$MODULE_DIR" -type f -name '*.ko*' | wc -l)"
[ "$MODULE_COUNT" -ge 100 ] || die "only $MODULE_COUNT kernel modules installed"
log "installed $MODULE_COUNT kernel modules"

# These point into the deleted source tree.
rm -f "$MODULE_DIR/build" "$MODULE_DIR/source"

mv "$ROOT_DIR/tmp/kernel_release" "$OUT_DIR/kernel_release"
mv "$ROOT_DIR/tmp/kernel_commit" "$OUT_DIR/kernel_commit"
