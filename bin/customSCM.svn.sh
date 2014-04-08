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
source ${LFS_CI_ROOT}/lib/customScm.common.sh
source ${LFS_CI_ROOT}/lib/customScm.svn.sh

# start the logfile
startLogfile
# and end it, if the script exited in some way
exit_add stopLogfile

action=$1
info "===== action = ${action} ====="

dumpCustomScmEnvironmentVariables

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
