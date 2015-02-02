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

action=$1

export LFS_CI_LOGGING_PREFIX=$(basename $0).${action}

export PATH=${LFS_CI_ROOT}/bin:${PATH}

source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/commands.sh
source ${LFS_CI_ROOT}/lib/exit_handling.sh
source ${LFS_CI_ROOT}/lib/customSCM.common.sh

initTempDirectory

fileBaseName=$(basename $0)

case "${fileBaseName}" in 
    customSCM.sh) source ${LFS_CI_ROOT}/lib/customSCM.upstream.sh  ;;
    *)
        if [[ -e ${LFS_CI_ROOT}/lib/${fileBaseName} ]] ; then
            source ${LFS_CI_ROOT}/lib/${fileBaseName}
        else 
            echo "can not find ${LFS_CI_ROOT}/lib/${fileBaseName}. exit"
            exit 1
        fi                
    ;;
esac

# start the logfile
startLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

trace "===== action = ${action} ====="
trace "workspace = ${WORKSPACE}"

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
