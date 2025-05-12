if [ $ROOT_DIR ]; then
    echo ROOT_DIR is "$ROOT_DIR"
else
    echo Error: ROOT_DIR is not set
    echo exit with error
    exit
fi

echo "################################################################################"
echo "# Up to 2.03"
echo "################################################################################"

chroot $ROOT_DIR <<- EOF_CHROOT

export DEBIAN_FRONTEND=noninteractive

pip3 install --upgrade pip --break-system-packages
pip3 install --upgrade notebook --break-system-packages
pip3 install --upgrade bokeh --break-system-packages
pip3 install --upgrade jupyterlab --break-system-packages
pip3 install --upgrade jupyterlab_server --break-system-packages
pip3 install --upgrade jupyterlab-widgets --break-system-packages
pip3 install --upgrade jupyterlab-pygments --break-system-packages
pip3 install --upgrade jupyter_core --break-system-packages
pip3 install --upgrade jupyter_client --break-system-packages

echo 2.03 > /root/.version

EOF_CHROOT

install -v -m 664 -o root -D $OVERLAY/usr/local/share/jupyter/kernels/python3/kernel.json      $ROOT_DIR/usr/local/share/jupyter/kernels/python3/kernel.json
