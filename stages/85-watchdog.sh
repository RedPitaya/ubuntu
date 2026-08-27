#!/usr/bin/env bash
# Enables the systemd hardware watchdog.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

write_rootfs_file etc/systemd/system.conf.d/watchdog.conf <<'EOF'
[Manager]
RuntimeWatchdogSec=5s
RebootWatchdogSec=10min
EOF
