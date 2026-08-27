#!/usr/bin/env bash
# Shared helpers. Sourced by build.sh and by every stage script.

set -Eeuo pipefail

: "${REPO_DIR:?REPO_DIR is not set}"
: "${OVERLAY:?OVERLAY is not set}"
: "${BOOT_DIR:?BOOT_DIR is not set}"
: "${ROOT_DIR:?ROOT_DIR is not set}"
: "${OUT_DIR:?OUT_DIR is not set}"

STAGE_NAME="$(basename -- "${BASH_SOURCE[1]:-build.sh}" .sh)"

log() { printf '[%s] %-18s %s\n' "$(date -u '+%H:%M:%S')" "$STAGE_NAME" "$*"; }
die() { printf '[%s] %-18s FATAL: %s\n' "$(date -u '+%H:%M:%S')" "$STAGE_NAME" "$*" >&2; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "must run as root"
}

require_cmd() {
    local cmd
    for cmd in "$@"; do
        command -v -- "$cmd" >/dev/null 2>&1 || die "missing host command: $cmd"
    done
}

# Runs the script read from stdin inside the target rootfs.
# Any failing command aborts the caller.
chroot_run() {
    [ -x "$ROOT_DIR/usr/bin/env" ] || die "rootfs is not usable: $ROOT_DIR"
    chroot "$ROOT_DIR" /usr/bin/env \
        DEBIAN_FRONTEND=noninteractive \
        DEBCONF_NOWARNINGS=yes \
        LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 \
        PIP_BREAK_SYSTEM_PACKAGES=1 \
        SYSTEMD_OFFLINE=1 \
        HOME=/root \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash -e -o pipefail -s
}

# install_overlay <path-in-overlay> [path-in-rootfs] [mode]
install_overlay() {
    local src="$1" dst="${2:-$1}" mode="${3:-0644}"
    [ -f "$OVERLAY/$src" ] || die "overlay file not found: $src"
    install -D -m "$mode" -o root -g root "$OVERLAY/$src" "$ROOT_DIR/$dst"
}

# copy_overlay_dir <dir-in-overlay> [dir-in-rootfs]
copy_overlay_dir() {
    local src="$1" dst="${2:-$1}"
    [ -d "$OVERLAY/$src" ] || die "overlay directory not found: $src"
    mkdir -p "$ROOT_DIR/$dst"
    cp -a "$OVERLAY/$src/." "$ROOT_DIR/$dst/"
}

# write_rootfs_file <path-in-rootfs> [mode], content on stdin
write_rootfs_file() {
    local dst="$1" mode="${2:-0644}"
    mkdir -p "$(dirname -- "$ROOT_DIR/$dst")"
    cat > "$ROOT_DIR/$dst"
    chmod "$mode" "$ROOT_DIR/$dst"
}

# patch_rootfs_file <sed-expression> <path-in-rootfs> <regex-required-afterwards>
patch_rootfs_file() {
    local expr="$1" dst="$2" expect="$3"
    [ -f "$ROOT_DIR/$dst" ] || die "file not found in rootfs: $dst"
    sed -i -E "$expr" "$ROOT_DIR/$dst"
    grep -qE "$expect" "$ROOT_DIR/$dst" || die "patch was not applied: $dst"
}

enable_units() {
    printf 'systemctl enable %s\n' "$@" | chroot_run
}

mount_pseudo() {
    local dir
    for dir in dev dev/pts proc sys run; do
        mkdir -p "$ROOT_DIR/$dir"
    done
    mountpoint -q "$ROOT_DIR/dev"     || mount --bind /dev     "$ROOT_DIR/dev"
    mountpoint -q "$ROOT_DIR/dev/pts" || mount --bind /dev/pts "$ROOT_DIR/dev/pts"
    mountpoint -q "$ROOT_DIR/proc"    || mount -t proc proc    "$ROOT_DIR/proc"
    mountpoint -q "$ROOT_DIR/sys"     || mount -t sysfs sys    "$ROOT_DIR/sys"
    mountpoint -q "$ROOT_DIR/run"     || mount --bind /run     "$ROOT_DIR/run"
}

unmount_pseudo() {
    local dir
    for dir in dev/pts dev proc sys run; do
        if mountpoint -q "$ROOT_DIR/$dir" 2>/dev/null; then
            umount -l "$ROOT_DIR/$dir" || log "warning: cannot unmount $dir"
        fi
    done
}

unmount_all() {
    local dir
    unmount_pseudo
    for dir in "$BOOT_DIR" "$ROOT_DIR"; do
        if mountpoint -q "$dir" 2>/dev/null; then
            fuser -km "$dir" >/dev/null 2>&1 || true
            sleep 1
            umount "$dir" 2>/dev/null || umount -l "$dir" || log "warning: cannot unmount $dir"
        fi
    done
}
