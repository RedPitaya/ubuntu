#!/usr/bin/env bash
# Red Pitaya Ubuntu OS image builder.
# Runs every script in stages/ in name order and fails on the first error.

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR
export LIB_DIR="$REPO_DIR/lib"
export STAGE_DIR="$REPO_DIR/stages"
export OVERLAY="$REPO_DIR/overlay"
export BOOT_DIR="$REPO_DIR/boot"
export ROOT_DIR="$REPO_DIR/root"
export OUT_DIR="$REPO_DIR/out"
export CACHE_DIR="$REPO_DIR/.cache"

export VERSION="${VERSION:-3.03}"
export BUILD_NUM="${BUILD_NUM:-${BUILD_NUMBER:-local}}"
export GIT_COMMIT="${GIT_COMMIT:-unknown}"
export DATE="${DATE:-$(date -u '+%Y-%b-%d_%H-%M-%S')}"
export TIMEZONE="${TIMEZONE:-Etc/UTC}"

export IMAGE_SIZE_MB="${IMAGE_SIZE_MB:-7400}"
export UBUNTU_BASE_VER="${UBUNTU_BASE_VER:-24.04.3}"
export KERNEL_URL="${KERNEL_URL:-https://github.com/RedPitaya/linux-xlnx}"
export KERNEL_BRANCH="${KERNEL_BRANCH:-branch-redpitaya-v2026-dev}"
export KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-redpitaya_zynq_defconfig}"
export KERNEL_KCFLAGS="${KERNEL_KCFLAGS:--O2 -march=armv7-a -mtune=cortex-a9}"
export KERNEL_CROSS_COMPILE="${KERNEL_CROSS_COMPILE:-arm-linux-gnueabihf-}"
export JUPYTER_URL="${JUPYTER_URL:-https://github.com/redpitaya/jupyter.git}"
export JUPYTER_BRANCH="${JUPYTER_BRANCH:-development}"
export BUILD_KERNEL_MODULES="${BUILD_KERNEL_MODULES:-1}"
export VERIFY_TOOLCHAIN="${VERIFY_TOOLCHAIN:-1}"

if [ "$BUILD_NUM" = "local" ]; then
    export IMAGE_NAME="red_pitaya_OS_${VERSION}"
else
    export IMAGE_NAME="red_pitaya_OS_${VERSION}.${BUILD_NUM}"
fi
export IMAGE="$OUT_DIR/${IMAGE_NAME}.img"
export BUILD_LOG="$OUT_DIR/build.log"
export BUILD_REPORT="$OUT_DIR/build_report.txt"

. "$LIB_DIR/common.sh"

run_stage() {
    local path="$1" name started
    name="$(basename -- "$path" .sh)"
    started=$SECONDS
    log "=== stage start: $name"
    bash "$path" || die "stage failed: $name"
    log "=== stage done : $name ($((SECONDS - started))s)"
}

prepare_workspace() {
    local dir
    unmount_all
    for dir in "$BOOT_DIR" "$ROOT_DIR"; do
        if mountpoint -q "$dir" 2>/dev/null; then
            die "still mounted: $dir"
        fi
        rm -rf "$dir"
        mkdir -p "$dir"
    done
    mkdir -p "$CACHE_DIR"
}

package_image() {
    log "packaging $IMAGE_NAME"
    printf 'Build Number: %s\nGit Commit: %s\nBuild Date: %s\nVersion: %s\nImage: %s\n' \
        "$BUILD_NUM" "$GIT_COMMIT" "$DATE" "$VERSION" "$IMAGE_NAME" > "$OUT_DIR/info.txt"
    md5sum "$IMAGE" | awk '{print $1}' > "$OUT_DIR/md5.txt"
    ( cd "$OUT_DIR" && zip -q "${IMAGE_NAME}.img.zip" \
        "${IMAGE_NAME}.img" info.txt md5.txt "$(basename -- "$BUILD_REPORT")" )
    log "artifacts:"
    ls -lh "$OUT_DIR"
}

# shellcheck disable=SC2329  # invoked through trap
on_exit() {
    local rc=$?
    trap - EXIT
    unmount_all
    [ "$rc" -eq 0 ] || log "build failed with exit code $rc"
    exit "$rc"
}

main() {
    local stage
    require_root
    require_cmd awk sed grep tar curl git zip md5sum dd sfdisk parted losetup \
        mkfs.vfat mkfs.ext4 mount umount mountpoint fuser chroot install modinfo
    trap on_exit EXIT
    log "building $IMAGE_NAME (build $BUILD_NUM, commit $GIT_COMMIT)"
    prepare_workspace
    for stage in "$STAGE_DIR"/[0-9][0-9]-*.sh; do
        [ -f "$stage" ] || die "no stage scripts found in $STAGE_DIR"
        run_stage "$stage"
    done
    unmount_all
    package_image
    log "build finished: $IMAGE_NAME"
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

rc=0
main 2>&1 | tee "$BUILD_LOG" || rc=$?

if ! bash "$LIB_DIR/check_log.sh" "$BUILD_LOG" 2>&1 | tee "$OUT_DIR/build_errors.txt"; then
    rc=1
fi

exit "$rc"
