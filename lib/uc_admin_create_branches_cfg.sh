#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh

## @fn      usecase_ADMIN_CREATE_BRANCHES_CFG()
#  @brief   usecase Admin - create etc/branches.cfg
#  @details the usecase is a little more complex as necessary to make it testable
#  @param   <none>
#  @return  <none>
usecase_ADMIN_CREATE_BRANCHES_CFG() {
    requiredParameters LFS_CI_ROOT WORKSPACE 

    local cfgFile=${WORKSPACE}/branches.cfg
    execute -n ${LFS_CI_ROOT}/bin/getBranchInformation > ${cfgFile}
    mustExistFile ${cfgFile}
    rawDebug ${cfgFile}

    local lineCount=$(wc -l ${cfgFile} | cut -d" " -f 1)
    mustHaveValue "${lineCount}" "numbers of lines in branches.cfg"
    if [[ ${lineCount} -lt 100 ]] ; then
        fatal "there must be a problem with branches.cfg. The branches.cfg has less than 100 lines."
    fi

    if execute -i cmp ${cfgFile} ${LFS_CI_ROOT}/etc/branches.cfg ; then
        info "no change detected in config file"
        return
    fi
        
    execute mv ${cfgFile} ${LFS_CI_ROOT}/etc/branches.cfg

    info "new branches.cfg successfully generated."

    return 0
}

