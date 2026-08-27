#!/usr/bin/env bash
# Unpacks Ubuntu base, enables ARM emulation and applies base configuration.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

require_cmd curl tar qemu-arm-static

BASE_TAR="ubuntu-base-${UBUNTU_BASE_VER}-base-armhf.tar.gz"
BASE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_BASE_VER}/release/${BASE_TAR}"
BASE_PATH="$CACHE_DIR/$BASE_TAR"

if [ ! -f "$BASE_PATH" ]; then
    log "downloading $BASE_URL"
    curl -fL --retry 3 -o "$BASE_PATH.part" "$BASE_URL"
    mv "$BASE_PATH.part" "$BASE_PATH"
fi

log "unpacking $BASE_TAR"
tar -xzf "$BASE_PATH" -C "$ROOT_DIR"
[ -x "$ROOT_DIR/bin/bash" ] || die "unpacked rootfs looks broken"

cp /etc/resolv.conf "$ROOT_DIR/etc/resolv.conf"
cp "$(command -v qemu-arm-static)" "$ROOT_DIR/usr/bin/"
mount_pseudo

write_rootfs_file root/.build_info <<EOF
Build Number: $BUILD_NUM
Git Commit: $GIT_COMMIT
Build Date: $DATE
Version: $VERSION
EOF

write_rootfs_file root/.version <<EOF
$VERSION
EOF

install_overlay etc/apt/apt.conf.d/99norecommends
install_overlay etc/hostname
install_overlay etc/fstab
install_overlay etc/securetty

log "installing base packages"
chroot_run <<'EOF'
apt-get update
apt-get install -y locales
echo 'LC_ALL=en_US.UTF-8' >> /etc/environment
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LANGUAGE=en_US LC_ALL=en_US.UTF-8

apt-get install -y apt-utils systemd systemd-sysv console-setup fake-hwclock tzdata
apt-get upgrade -y

ln -sf /lib/systemd/systemd /sbin/init
systemctl set-default multi-user.target
echo 'root:root' | chpasswd
EOF

log "setting timezone $TIMEZONE"
chroot_run <<EOF
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
EOF

date -u '+%F %T' > "$ROOT_DIR/etc/fake-hwclock.data"
