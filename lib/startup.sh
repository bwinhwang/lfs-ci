#!/bin/bash

source ${LFS_CI_ROOT}/lib/common.sh
source ${LFS_CI_ROOT}/lib/logging.sh
source ${LFS_CI_ROOT}/lib/commands.sh
source ${LFS_CI_ROOT}/lib/config.sh
source ${LFS_CI_ROOT}/lib/jenkins.sh
source ${LFS_CI_ROOT}/lib/subversion.sh

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

        source ${seesetenv} ${selectedLinseeTools}
    fi

    return
}

