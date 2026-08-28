#!/usr/bin/env bash
# Scans a build log for fatal patterns. Exits non-zero when any are found.
# Usage: check_log.sh <build log>

set -Eeuo pipefail

LOG="${1:?usage: check_log.sh <build log>}"
[ -f "$LOG" ] || { echo "check_log: file not found: $LOG" >&2; exit 1; }

MAX_LINES=40

# Known harmless noise, dropped before matching.
IGNORE='dpkg-preconfigure: unable to re-open stdin'
IGNORE="$IGNORE"'|debconf: (delaying package configuration|falling back|unable to initialize frontend)'
IGNORE="$IGNORE"'|^(N|Get|Hit|Ign|Selecting|Preparing|Unpacking|Setting up|Processing|Suggested|Recommended) '
IGNORE="$IGNORE"'|Download is performed unsandboxed'
IGNORE="$IGNORE"'|update-alternatives: (warning|using)'
IGNORE="$IGNORE"'|^\s*(Building|Created|Stored|Requirement already satisfied)'
# parted calls udevadm, which is absent in a chroot and in a minimal container
IGNORE="$IGNORE"'|udevadm: command not found'
# printed by every pip call in the image build
IGNORE="$IGNORE"'|Running pip as the .root. user'
# the locale is generated inside the rootfs after the first packages install
IGNORE="$IGNORE"'|setlocale: LC_ALL: cannot change locale'
IGNORE="$IGNORE"'|perl: warning: (Setting locale failed|Please check that your locale|Falling back to the standard locale)'
IGNORE="$IGNORE"'|LANGUAGE = |LC_ALL = |LANG = |are supported and installed'

FATAL='^E: '
FATAL="$FATAL"'|^dpkg: error|dpkg: dependency problems'
FATAL="$FATAL"'|Unable to locate package|Unable to correct problems|unmet dependencies'
FATAL="$FATAL"'|Sub-process .* returned an error code'
FATAL="$FATAL"'|No space left on device'
FATAL="$FATAL"'|Segmentation fault|qemu: uncaught target signal'
FATAL="$FATAL"'|^make(\[[0-9]+\])?: \*\*\*'
FATAL="$FATAL"'|error: subprocess-exited-with-error|ERROR: Failed building wheel|ERROR: Could not build wheels'
FATAL="$FATAL"'|ERROR: Could not find a version|No matching distribution found'
FATAL="$FATAL"'|^fatal: |Traceback \(most recent call last\)'
FATAL="$FATAL"'|command not found|FATAL: '

WARN='^W: |warning: |WARNING: |deprecated'

echo "=== build log check: $LOG"

clean="$(grep -vE -- "$IGNORE" "$LOG" || true)"
fatal_hits="$(printf '%s\n' "$clean" | grep -Ei -- "$FATAL" || true)"
warn_hits="$(printf '%s\n' "$clean" | grep -E -- "$WARN" || true)"

fatal_count=0
warn_count=0
[ -z "$fatal_hits" ] || fatal_count="$(printf '%s\n' "$fatal_hits" | wc -l)"
[ -z "$warn_hits" ] || warn_count="$(printf '%s\n' "$warn_hits" | wc -l)"

echo "warnings: $warn_count"
[ "$warn_count" -eq 0 ] || printf '%s\n' "$warn_hits" | head -n "$MAX_LINES"

echo "errors: $fatal_count"
if [ "$fatal_count" -ne 0 ]; then
    printf '%s\n' "$fatal_hits" | head -n "$MAX_LINES"
    echo "=== build log check: FAILED"
    exit 1
fi

echo "=== build log check: OK"
