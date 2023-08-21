echo 'Enable watchdog'

sed -i 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=5s/g' $ROOT_DIR/etc/systemd/system.conf
sed -i 's/#RebootWatchdogSec=10min/RebootWatchdogSec=10min/g' $ROOT_DIR/etc/systemd/system.conf
