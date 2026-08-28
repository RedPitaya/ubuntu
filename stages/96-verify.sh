#!/usr/bin/env bash
# Verifies the built rootfs. Any missing piece fails the build.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

FAILURES=0

fail() {
    log "CHECK FAILED: $*"
    FAILURES=$((FAILURES + 1))
}

require_paths() {
    local path
    for path in "$@"; do
        [ -e "$ROOT_DIR/$path" ] || [ -L "$ROOT_DIR/$path" ] || fail "missing path: $path"
    done
}

log "checking required files"
require_paths \
    sbin/init \
    etc/fstab \
    etc/hostname \
    etc/securetty \
    etc/fw_env.config \
    etc/motd \
    etc/timezone \
    etc/fake-hwclock.data \
    etc/apt/apt.conf.d/99norecommends \
    etc/profile.d/redpitaya.sh \
    etc/udev/rules.d/10-redpitaya.rules \
    etc/modprobe.d/rtw88.conf \
    etc/iptables/iptables.rules \
    etc/mdns.allow \
    etc/ssh/sshd_config.d/10-redpitaya.conf \
    etc/systemd/resolved.conf.d/mdns.conf \
    etc/systemd/system.conf.d/watchdog.conf \
    etc/systemd/system/jupyter.service \
    etc/systemd/system/redpitaya_nginx.service \
    etc/systemd/system/serial-getty@ttyPS0.service.d/autologin.conf \
    usr/lib/systemd/scripts/iptables-flush \
    usr/local/sbin/rp-wireless-driver \
    usr/local/share/jupyter/kernels/python3/kernel.json \
    root/.jupyter/jupyter_notebook_config.py \
    root/.build_info \
    root/build_report.txt \
    home/jupyter/.jupyter/jupyter_notebook_config.py \
    home/jupyter/RedPitaya \
    home/jupyter/WhirlwindTourOfPython \
    lib/firmware/rtw88 \
    var/log/redpitaya_nginx

[ -x "$ROOT_DIR/usr/lib/systemd/scripts/iptables-flush" ] || fail "iptables-flush is not executable"
[ -x "$ROOT_DIR/usr/local/sbin/rp-wireless-driver" ] || fail "rp-wireless-driver is not executable"

log "checking package database"
if ! chroot_run <<'EOF'
broken="$(dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' | grep -vE '^(ii|rc) ' || true)"
if [ -n "$broken" ]; then
    echo "$broken"
    exit 1
fi
EOF
then
    fail "packages are not fully installed"
fi

log "checking users and groups"
if ! chroot_run <<'EOF'
for user in redpitaya jupyter redpitaya_nginx scpi; do
    id "$user" >/dev/null
done
for group in xdevcfg uio led gpio spi eeprom xadc dma i2c kmem; do
    getent group "$group" >/dev/null
done
EOF
then
    fail "users or groups are missing"
fi

log "checking enabled units"
if ! chroot_run <<'EOF'
units="
systemd-networkd.service
systemd-resolved.service
avahi-daemon.service
hostname-mac.service
ssh-reconfigure.service
iptables.service
jupyter.service
redpitaya_nginx.service
redpitaya_startup.service
redpitaya_e3_controller.service
sockproc.service
wireless-mode-client.service
wireless-mode-ap.service
wireless_adapter_up@wlan0.service
wpa_supplicant@wlan0.service
wpa_supplicant_wext@wlan0.service
wifi-powersave@wlan0.service
hostapd@wlan0.service
"
rc=0
for unit in $units; do
    state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    case "$state" in
        enabled|enabled-runtime|alias|static|indirect) continue ;;
    esac
    if find /etc/systemd/system -maxdepth 2 -type l -name "$unit" | grep -q .; then
        continue
    fi
    echo "unit not enabled: $unit ($state)"
    rc=1
done

# ntp/ntpsec replaces systemd-timesyncd, so accept whichever is installed.
time_daemon=0
for unit in ntpsec.service ntp.service systemd-timesyncd.service; do
    if systemctl is-enabled "$unit" >/dev/null 2>&1; then
        time_daemon=1
        break
    fi
done
if [ "$time_daemon" -eq 0 ]; then
    echo "no time synchronisation service is enabled"
    rc=1
fi

exit $rc
EOF
then
    fail "some units are not enabled"
fi

log "checking python modules"
if ! chroot_run <<'EOF'
python3 -c 'import importlib.util, sys
mods = ["numpy", "scipy", "pandas", "matplotlib", "bokeh", "notebook",
        "jupyterlab", "ipywidgets", "jupyter_bokeh", "periphery", "smbus2",
        "pyudev", "vcd", "nptdms"]
missing = [m for m in mods if importlib.util.find_spec(m) is None]
if missing:
    sys.exit("missing python modules: " + ", ".join(missing))'
python3 -c 'import numpy, matplotlib; print("numpy", numpy.__version__, "matplotlib", matplotlib.__version__)'
EOF
then
    fail "python modules are missing"
fi

if [ "${VERIFY_TOOLCHAIN:-1}" = "1" ]; then
    # The ecosystem builds its Python bindings with swig -python -c++ -threads -O
    # and g++ -std=c++20 against the numpy headers of this image.
    log "checking swig, python headers and numpy headers"
    if ! chroot_run <<'EOF'
work="$(mktemp -d)"
cd "$work"
cat > check.i <<'IFACE'
%module swigcheck
%{
#define SWIG_FILE_WITH_INIT
#define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
#include <numpy/arrayobject.h>
%}
%init %{
import_array();
%}
%inline %{
int sum_int16(PyObject *obj)
{
    PyArrayObject *arr = (PyArrayObject *)PyArray_FROM_OTF(obj, NPY_INT16, NPY_ARRAY_IN_ARRAY);
    if (arr == NULL) {
        return -1;
    }
    npy_intp count = PyArray_SIZE(arr);
    const npy_int16 *data = (const npy_int16 *)PyArray_DATA(arr);
    int total = 0;
    for (npy_intp i = 0; i < count; ++i) {
        total += data[i];
    }
    Py_DECREF(arr);
    return total;
}
%}
IFACE
swig -python -c++ -threads -O -o check_wrap.cxx check.i
g++ -std=c++20 -fPIC -shared check_wrap.cxx -o _swigcheck.so \
    $(python3-config --includes) \
    -I"$(python3 -c 'import numpy; print(numpy.get_include())')"
PYTHONPATH="$work" python3 -c '
import numpy, swigcheck
total = swigcheck.sum_int16(numpy.array([1, 2, 3], dtype=numpy.int16))
assert total == 6, total
print("swig", "+ numpy", numpy.__version__, "+ python headers: ok")
'
cd /
rm -rf "$work"
EOF
    then
        fail "swig, python headers or numpy headers are unusable"
    fi
fi

if [ "$BUILD_KERNEL_MODULES" = "1" ]; then
    log "checking kernel modules"
    release="$(cat "$OUT_DIR/kernel_release" 2>/dev/null || true)"
    [ -n "$release" ] || fail "kernel release is unknown"
    if [ -n "$release" ]; then
        [ -f "$ROOT_DIR/lib/modules/$release/modules.dep" ] || fail "modules.dep is missing"
        count="$(find "$ROOT_DIR/lib/modules/$release" -type f -name '*.ko*' | wc -l)"
        expected="$(cat "$OUT_DIR/kernel_module_count" 2>/dev/null || echo 0)"
        log "installed kernel modules: $count"
        [ "$count" -gt 0 ] || fail "no kernel modules installed"
        [ "$expected" -eq 0 ] || [ "$count" -eq "$expected" ] \
            || fail "expected $expected kernel modules, found $count"
    fi
fi

[ -s "$BUILD_REPORT" ] || fail "build report is empty"

[ "$FAILURES" -eq 0 ] || die "$FAILURES check(s) failed"
log "all checks passed"
