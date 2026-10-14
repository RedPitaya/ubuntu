#!/usr/bin/env bash
# Enables the systemd hardware watchdog.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

# cdns_wdt max timeout is 516 s; a larger value makes systemd disarm the watchdog on reboot.
write_rootfs_file etc/systemd/system.conf.d/watchdog.conf <<'EOF'
[Manager]
RuntimeWatchdogSec=5s
RebootWatchdogSec=5min
EOF
