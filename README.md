# Ubuntu OS image for Red Pitaya

Builds a bootable SD card image with Ubuntu 24.04 (armhf) for Red Pitaya
boards based on Xilinx Zynq.

## Layout

```
build.sh                 orchestrator, runs every stage in order
lib/common.sh            shared helpers (chroot, overlay install, mounts)
lib/check_log.sh         final build log scan, fails the build on errors
stages/                  build stages, executed in name order
overlay/                 files copied verbatim into the image
tools/                   maintenance helpers for finished images
dev_scripts/             development helpers, not part of the build
```

### Stages

| Stage                | Purpose                                              |
| -------------------- | ---------------------------------------------------- |
| `00-image`           | create image file, partition, format, mount          |
| `10-rootfs`          | unpack Ubuntu base, ARM emulation, locale, time      |
| `20-tools`           | general purpose user space tools                     |
| `30-dev-tools`       | Python and the native build toolchain                |
| `40-network`         | systemd-networkd, SSH, WiFi client/AP, mDNS          |
| `50-zynq`            | Zynq tools, hardware groups, default user            |
| `60-redpitaya`       | Bazaar/SCPI dependencies, services, daemon users     |
| `70-jupyter`         | JupyterLab, scientific Python stack, examples        |
| `80-wireless`        | wireless tools and device bound units                |
| `85-watchdog`        | systemd hardware watchdog                            |
| `90-kernel-modules`  | cross compile kernel modules, install firmware       |
| `93-report`          | collect package, module and unit versions            |
| `96-verify`          | verify the produced rootfs                           |
| `99-finalize`        | clean rootfs, drop emulation, create rootfs tarball  |

## Requirements

- Docker (the build runs as root inside a privileged container)
- 30 GB free disk space
- Loop device support on the host

## Building

```bash
./docker_build.sh
```

Artifacts are collected in `artifacts/`. To build directly on an Ubuntu 24.04
host (needs root and the packages listed in the `Dockerfile`):

```bash
sudo ./build.sh
```

Output goes to `out/`:

| File                            | Content                                     |
| ------------------------------- | ------------------------------------------- |
| `red_pitaya_OS_<version>.img`   | SD card image                               |
| `red_pitaya_OS_<version>.img.zip` | image, `info.txt`, `md5.txt`, build report |
| `red_pitaya_OS_<version>.tar.gz`| root file system tarball                    |
| `build.log`                     | full build log                              |
| `build_report.txt`              | versions of everything installed            |
| `build_errors.txt`              | result of the build log scan                |
| `packages_apt.txt`              | apt packages with versions                  |
| `packages_pip.txt`              | pip packages with versions                  |
| `kernel_modules.txt`            | installed kernel modules                    |
| `enabled_units.txt`             | enabled systemd units                       |

`build_report.txt` is also kept inside the image as `/root/build_report.txt`.

## Error handling

- every stage runs with `set -Eeuo pipefail`, and commands inside the target
  rootfs run with `bash -e -o pipefail`, so a failing command stops the build
- `build.sh` aborts on the first failing stage and always unmounts the image
- `96-verify` checks files, packages, users, units, Python modules and kernel
  modules in the produced rootfs
- `lib/check_log.sh` scans the whole build log for known fatal patterns and
  fails the build even when a tool exited with code 0

## Configuration

Overridable environment variables (see the top of `build.sh` for defaults):
`VERSION`, `BUILD_NUM`, `GIT_COMMIT`, `TIMEZONE`, `IMAGE_SIZE_MB`,
`UBUNTU_BASE_VER`, `KERNEL_URL`, `KERNEL_BRANCH`, `KERNEL_DEFCONFIG`,
`KERNEL_CROSS_COMPILE`, `JUPYTER_URL`, `JUPYTER_BRANCH`,
`BUILD_KERNEL_MODULES`.

Downloads are cached in `.cache/` between local builds.
