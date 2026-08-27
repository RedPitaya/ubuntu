export PATH_REDPITAYA=/opt/redpitaya
export PATH=$PATH:$PATH_REDPITAYA/sbin:$PATH_REDPITAYA/bin
export PYTHONPATH=/opt/redpitaya/lib/python/:$PYTHONPATH
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PATH_REDPITAYA/lib

if [[ -f $PATH_REDPITAYA/bin/production_testing_script.sh ]]
then
  cd $PATH_REDPITAYA/bin
  ./production_testing_script.sh
fi
