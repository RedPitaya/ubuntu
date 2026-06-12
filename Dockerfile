# Use the officially supported Ubuntu 24.04 base image
FROM ubuntu:24.04

# Disable interactive frontend prompts during package installations
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NOWARNINGS=yes

# Set bash as the default shell (fixes "history: not found" in dash)
SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

# Suppress debconf warnings about missing kernel modules
ENV CONFIG_SITE=/etc/dpkg-cross/cross-config.arm64
RUN echo 'ac_cv_prog_LSMOD=lsmod' >> /etc/dpkg-cross/cross-config.arm64 2>/dev/null || true

# Install all build toolchain dependencies, cross-compilation layers, and disk partitioning utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    bison \
    build-essential \
    curl \
    dosfstools \
    flex \
    git \
    kmod \
    libncurses5-dev \
    libssl-dev \
    locales \
    inotify-tools \
    parted \
    psmisc \
    python3-pip \
    util-linux \
    qemu-user-static \
    rsync \
    schroot \
    fdisk \
    sudo \
    udev \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Ensure /bin/sh points to bash (Ubuntu uses dash by default)
RUN ln -sf /bin/bash /bin/sh

# Generate and configure the missing en_US.UTF-8 locale to prevent layout errors
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Copy only required build files and directories into the image for full isolation
# This ensures the container is self-sufficient without mounting host source code
COPY build.sh /build/
COPY debian/ /build/debian/
COPY dev_scripts/ /build/dev_scripts/

# Ensure all shell scripts have execute permissions
RUN chmod +x *.sh dev_scripts/*.sh debian/*.sh 2>/dev/null || true

# Set up the internal work directory
WORKDIR /build

# Execute the default build script using bash explicitly
CMD ["/bin/bash", "./build.sh"]