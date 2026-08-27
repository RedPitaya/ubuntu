#!/usr/bin/env bash
# JupyterLab, the scientific Python stack and the notebook examples.

set -Eeuo pipefail
. "${LIB_DIR:?run this through build.sh}/common.sh"

PIP_PINS=tmp/pip-constraints.txt

install_overlay etc/systemd/system/jupyter.service
install_overlay home/jupyter/.jupyter/jupyter_notebook_config.py \
    root/.jupyter/jupyter_notebook_config.py
install_overlay home/jupyter/.jupyter/jupyter_notebook_config.py
install_overlay usr/local/share/jupyter/kernels/python3/kernel.json

# Single source of truth for the python versions in the image. Passed to every
# pip call as PIP_CONSTRAINT, so a transitive dependency can never pull another
# version. IPython, bokeh, ipywidgets, numpy and scipy are pinned by the
# notebook examples package as well, keep both sides in sync.
write_rootfs_file "$PIP_PINS" <<'EOF'
IPython==9.16.1
bokeh==3.9.2
contourpy==1.3.3
cython==3.3.0
i2cdev==1.2.4
ipywidgets==8.1.9
jupyter_bokeh==4.1.0
jupyter_client==8.9.1
jupyter_core==5.9.1
jupyterlab==4.6.3
jupyterlab-pygments==0.3.0
jupyterlab-widgets==3.0.17
jupyterlab_server==2.28.0
matplotlib==3.11.1
meson-python==0.20.0
meson==1.12.0
notebook==7.6.2
nptdms==1.11.0
numpy==2.4.6
pandas==3.0.5
pybind11==3.1.0
pyfdt==0.3
python-periphery==2.4.1
pyudev==0.24.4
pyvcd==0.5.0
qtconsole==5.7.2
scipy==1.17.1
smbus2==0.6.1
EOF

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
export PIP_CONSTRAINT=/tmp/pip-constraints.txt
pip3 install meson meson-python pybind11 cython
EOF

# numpy has no armhf wheel and is built from source, so it must be installed
# before anything that depends on it. Installing contourpy first would pull the
# newest numpy as a dependency and build it a second time.
log "installing numpy and contourpy"
chroot_run <<'EOF'
export PIP_CONSTRAINT=/tmp/pip-constraints.txt
pip3 install numpy
pip3 install contourpy --no-build-isolation
EOF

log "installing scientific python stack"
chroot_run <<'EOF'
export PIP_CONSTRAINT=/tmp/pip-constraints.txt
pip3 install scipy pandas matplotlib
EOF

log "installing jupyter stack"
chroot_run <<'EOF'
export PIP_CONSTRAINT=/tmp/pip-constraints.txt
pip3 install IPython
pip3 install notebook jupyterlab jupyterlab_server
pip3 install ipywidgets jupyterlab-widgets jupyterlab-pygments
pip3 install jupyter_core jupyter_client qtconsole
pip3 install bokeh jupyter_bokeh
EOF

log "installing hardware access modules"
chroot_run <<'EOF'
export PIP_CONSTRAINT=/tmp/pip-constraints.txt
pip3 install python-periphery smbus2 i2cdev pyvcd pyudev pyfdt nptdms
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
export PIP_CONSTRAINT=/tmp/pip-constraints.txt
# --no-deps: the pinned versions are the single source of truth, the pins in
# the examples package must not re-resolve the whole stack.
pip3 install -e /home/jupyter/RedPitaya --no-build-isolation --no-deps
chown -R jupyter:jupyter /home/jupyter
systemctl enable jupyter.service
EOF
