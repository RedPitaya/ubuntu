#!/usr/bin/env bash
# JupyterLab, the scientific Python stack and the notebook examples.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

install_overlay etc/systemd/system/jupyter.service
install_overlay home/jupyter/.jupyter/jupyter_notebook_config.py \
    root/.jupyter/jupyter_notebook_config.py
install_overlay home/jupyter/.jupyter/jupyter_notebook_config.py
install_overlay usr/local/share/jupyter/kernels/python3/kernel.json

log "installing native dependencies"
chroot_run <<'EOF'
apt-get install -y \
    gfortran \
    libffi-dev \
    libffi8 \
    libjpeg-dev \
    liblapack-dev \
    libopenblas-dev \
    libpng-dev \
    libsigrok4t64 \
    libsigrokdecode4 \
    sigrok-cli \
    zlib1g-dev
EOF

log "installing build helpers for python wheels"
chroot_run <<'EOF'
pip3 install meson==1.6.1
pip3 install meson-python==0.17.1
pip3 install pybind11==2.13.6
pip3 install cython==3.0.11
pip3 install contourpy==1.3.1 -U --no-build-isolation
EOF

log "installing jupyter stack"
chroot_run <<'EOF'
pip3 install notebook==7.3.2
pip3 install jupyterlab==4.3.4
pip3 install ipywidgets==8.1.8
pip3 install qtconsole==5.6.1
pip3 install bokeh==3.8.2
pip3 install jupyterlab_server==2.27.3
pip3 install jupyterlab-widgets==3.0.15
pip3 install jupyterlab-pygments==0.3.0
pip3 install jupyter_core==5.9.1
pip3 install jupyter_client==8.8.0
pip3 install jupyter_bokeh==4.0.5
EOF

log "installing scientific python stack"
chroot_run <<'EOF'
pip3 install numpy==2.4.1
pip3 install scipy==1.17.0
pip3 install pandas==3.0.0
pip3 install matplotlib==3.10.0
EOF

log "installing hardware access modules"
chroot_run <<'EOF'
pip3 install python-periphery==2.4.1
pip3 install smbus2==0.5.0
pip3 install i2cdev==1.2.4
pip3 install pyvcd==0.4.1
pip3 install pyudev==0.24.3
pip3 install pyfdt==0.3
pip3 install nptdms
EOF

log "creating jupyter user"
chroot_run <<'EOF'
id jupyter >/dev/null 2>&1 || useradd -m -c "Jupyter notebook user" -s /bin/bash \
    -G xdevcfg,uio,xadc,led,gpio,spi,i2c,eeprom,dialout,dma jupyter
EOF

log "cloning notebook examples"
rm -rf "$ROOT_DIR/home/jupyter/RedPitaya" "$ROOT_DIR/home/jupyter/WhirlwindTourOfPython"
# Full clone: the editable install may derive its version from git metadata.
git clone -b "$JUPYTER_BRANCH" "$JUPYTER_URL" "$ROOT_DIR/home/jupyter/RedPitaya"
git clone --depth 1 https://github.com/jakevdp/WhirlwindTourOfPython.git \
    "$ROOT_DIR/home/jupyter/WhirlwindTourOfPython"
git -C "$ROOT_DIR/home/jupyter/RedPitaya" rev-parse HEAD > "$OUT_DIR/jupyter_examples_commit"

chroot_run <<'EOF'
pip3 install -e /home/jupyter/RedPitaya --no-build-isolation
chown -R jupyter:jupyter /home/jupyter
systemctl enable jupyter.service
EOF
