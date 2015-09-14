#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/commands.sh
source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

## @fn      prepareStartup()
#  @brief   prepare startup of a jenkins ci script run
#  @details this function is setting up some requirements for the
#           script run. 
#           * set debug bash prompt
#           * dump environment varables and settings
#           * install common exit handlers
#  @param   <none>
#  @return  <none>
prepareStartup() {
    export PATH=${LFS_CI_ROOT}/bin:${PATH}

    # load the properties from the custom SCM jenkins plugin
    if [[ -f ${WORKSPACE}/.properties ]] ; then
        source ${WORKSPACE}/.properties
    fi

    # start the logfile
    initTempDirectory
    startLogfile
    # and end it, if the script exited in some way
    exit_add stopLogfile
    exit_add logRerunCommand

    # for better debugging
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    export PS4

    requiredParameters LFS_CI_ROOT JOB_NAME HOSTNAME USER 

    showAllEnvironmentVariables
    sanityCheck

    info "starting jenkins job \"${JOB_NAME}\" on ${HOSTNAME} as ${USER}"
    if [[ "${UPSTREAM_PROJECT}" && "${UPSTREAM_BUILD}" ]] ; then
        info "upstream job ${UPSTREAM_PROJECT} / ${UPSTREAM_BUILD}"
    fi

    # we can define in the configuration, which tools we want to use for different
    # usecases. This tools must be available via LINSEE. 
    local selectedLinseeTools=$(getConfig LINSEE_selected_tools)
    if [[ ${selectedLinseeTools} ]] ; then
        local seesetenv=$(getConfig LINSEE_cmd_seesetenv)
        mustExistFile ${seesetenv}
        
        info "using ${selectedLinseeTools} from LINSEE"

        source ${seesetenv} ${selectedLinseeTools}
    fi

    # TODO: demx2fk3 2015-07-27 workaround - remove me
    if [[ -z ${LFS_CI_CONFIG_FILE} ]] ; then
        export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-ci.cfg
    fi

    # we always require a config file. 
    requiredParameters LFS_CI_CONFIG_FILE

    return
}

