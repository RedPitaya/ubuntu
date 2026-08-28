FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NOWARNINGS=yes
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV SHELL=/bin/bash
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dosfstools \
    e2fsprogs \
    fdisk \
    git \
    kmod \
    locales \
    parted \
    psmisc \
    qemu-user-static \
    udev \
    util-linux \
    xz-utils \
    zip \
    zstd \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
RUN ln -sf /bin/bash /bin/sh

WORKDIR /build

COPY build.sh /build/
COPY lib/ /build/lib/
COPY stages/ /build/stages/
COPY overlay/ /build/overlay/
COPY tools/ /build/tools/

RUN chmod +x /build/build.sh /build/lib/*.sh /build/stages/*.sh /build/tools/*.sh

CMD ["/build/build.sh"]
