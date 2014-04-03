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
source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/customScm.sh

action=$1
info "===== action = ${action} ====="

dumpCustomScmEnvironmentVariables

if [[ ${action} == compare ]] ; then

    # TODO: demx2fk3 2014-04-03 add compare action
    # TODO: demx2fk3 2014-04-03 always trigger a new build
    exit 0

fi

if [[ ${action} == checkout ]] ; then
    actionCheckout
fi

if [[ ${action} == calculate ]] ; then
    actionCalculate
fi

exit 0
