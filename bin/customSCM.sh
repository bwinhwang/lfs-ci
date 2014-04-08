#!/bin/bash

# script for CustomSCM Jenkins Plugins
# see https://bts.inside.nsn.com/twiki/bin/view/MacPsWmp/CiInternals#The_CustomSCM_Plugin

# action description:
# * compare
#   this script is started by jenkins in polling action. It checks, if there
#   is a build needed. 

# * calculate
#   see web page

# * checkout
#   see web page

source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/commands.sh
source ${LFS_CI_ROOT}/lib/exit_handling.sh
source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/customSCM.common.sh

fileBaseName=$(basename $0)

case "${fileBaseName}" in 
    customSCM.svn.sh)      source ${LFS_CI_ROOT}/lib/customSCM.svn.sh      ;;
    customSCM.upstream.sh) source ${LFS_CI_ROOT}/lib/customSCM.upstream.sh ;;
    customSCM.sh)          source ${LFS_CI_ROOT}/lib/customSCM.sh          ;;
    *)
        echo "can not found ${LFS_CI_ROOT}/lib/${fileBaseName}. exit"
        exit 1
    ;;
esac

# start the logfile
startLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

action=$1
info "===== action = ${action} ====="

# TODO: demx2fk3 2014-04-08 for debugging
# dumpCustomScmEnvironmentVariables

if [[ ${action} == compare ]] ; then
    actionCompare
fi

if [[ ${action} == checkout ]] ; then
    actionCheckout
fi

if [[ ${action} == calculate ]] ; then
    actionCalculate
fi

exit 0
