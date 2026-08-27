#!/usr/bin/env bash
# Collects the versions of everything installed into the image and writes
# the build report. A copy is kept inside the image as /root/build_report.txt.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

APT_FILE="$OUT_DIR/packages_apt.txt"
PIP_FILE="$OUT_DIR/packages_pip.txt"
MOD_FILE="$OUT_DIR/kernel_modules.txt"
UNIT_FILE="$OUT_DIR/enabled_units.txt"

log "collecting apt package versions"
chroot_run > "$APT_FILE" <<'EOF'
dpkg-query -W -f='${db:Status-Abbrev}\t${binary:Package}\t${Version}\n' \
    | grep '^ii' | cut -f2,3 | sort
EOF

log "collecting pip package versions"
chroot_run > "$PIP_FILE" <<'EOF'
pip3 list --format=freeze --disable-pip-version-check | sort
EOF

if [ -d "$ROOT_DIR/lib/modules" ]; then
    ( cd "$ROOT_DIR/lib/modules" && find . -type f -name '*.ko*' -printf '%P\n' | sort ) > "$MOD_FILE"
else
    : > "$MOD_FILE"
fi

( cd "$ROOT_DIR/etc/systemd/system" && find . -type l -printf '%P\n' | sort ) > "$UNIT_FILE"

read_file() { [ -f "$1" ] && cat "$1" || echo unknown; }

KERNEL_RELEASE="$(read_file "$OUT_DIR/kernel_release")"
KERNEL_COMMIT="$(read_file "$OUT_DIR/kernel_commit")"
JUPYTER_COMMIT="$(read_file "$OUT_DIR/jupyter_examples_commit")"

VERMAGIC=unknown
SAMPLE_MOD="$(find "$ROOT_DIR/lib/modules" -type f -name '*.ko*' -print -quit 2>/dev/null || true)"
if [ -n "$SAMPLE_MOD" ]; then
    VERMAGIC="$(modinfo -F vermagic "$SAMPLE_MOD" 2>/dev/null || echo unknown)"
fi

APT_COUNT="$(wc -l < "$APT_FILE")"
PIP_COUNT="$(wc -l < "$PIP_FILE")"
MOD_COUNT="$(wc -l < "$MOD_FILE")"
UNIT_COUNT="$(wc -l < "$UNIT_FILE")"
ROOTFS_SIZE="$(du -shx "$ROOT_DIR" | awk '{print $1}')"
DEFAULT_TARGET="$(basename -- "$(readlink -f "$ROOT_DIR/etc/systemd/system/default.target" 2>/dev/null || echo unknown)")"

section() { printf '\n--- %s %s\n' "$1" "$(printf '%*s' $((72 - ${#1})) '' | tr ' ' '-')"; }

{
    printf '================================================================================\n'
    printf 'Red Pitaya Ubuntu OS build report\n'
    printf '================================================================================\n'
    printf 'Image name        : %s\n' "$IMAGE_NAME"
    printf 'OS version        : %s\n' "$VERSION"
    printf 'Build number      : %s\n' "$BUILD_NUM"
    printf 'Git commit        : %s\n' "$GIT_COMMIT"
    printf 'Build date (UTC)  : %s\n' "$DATE"
    printf 'Timezone          : %s\n' "$TIMEZONE"
    printf 'Ubuntu base       : %s armhf\n' "$UBUNTU_BASE_VER"
    printf 'Kernel source     : %s @ %s\n' "$KERNEL_URL" "$KERNEL_BRANCH"
    printf 'Kernel commit     : %s\n' "$KERNEL_COMMIT"
    printf 'Kernel release    : %s\n' "$KERNEL_RELEASE"
    printf 'Module vermagic   : %s\n' "$VERMAGIC"
    printf 'Notebooks source  : %s @ %s\n' "$JUPYTER_URL" "$JUPYTER_BRANCH"
    printf 'Notebooks commit  : %s\n' "$JUPYTER_COMMIT"
    printf 'Default target    : %s\n' "$DEFAULT_TARGET"
    printf 'Rootfs size       : %s\n' "$ROOTFS_SIZE"

    section 'summary'
    printf 'apt packages      : %s\n' "$APT_COUNT"
    printf 'pip packages      : %s\n' "$PIP_COUNT"
    printf 'kernel modules    : %s\n' "$MOD_COUNT"
    printf 'enabled units     : %s\n' "$UNIT_COUNT"

    section 'apt packages (name version)'
    cat "$APT_FILE"

    section 'pip packages (name==version)'
    cat "$PIP_FILE"

    section 'enabled systemd units'
    cat "$UNIT_FILE"

    section "kernel modules (built for $KERNEL_RELEASE)"
    cat "$MOD_FILE"
} > "$BUILD_REPORT"

install -D -m 0644 "$BUILD_REPORT" "$ROOT_DIR/root/build_report.txt"

log "report: $APT_COUNT apt, $PIP_COUNT pip, $MOD_COUNT modules, $UNIT_COUNT units, rootfs $ROOTFS_SIZE"
