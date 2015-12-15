#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

## @fn      usecase_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE()
#  @brief   usecase to create a new LFS CI eecloud slave (https://psweb.nsn-net.net/PS/Wiki/doku.php?id=lfs:production:ci_version2:howto_setup_new_cloud_server)
#  @param   <none>
#  @return  <none>
usecase_ADMIN_CREATE_CLOUD_SLAVE_INSTANCE() {

    local cloudLfs2Cloud=$(getConfig LFS_CI_CLOUD_LFS2CLOUD)
    mustHaveValue "${cloudLfs2Cloud}" "cloudLfs2Cloud"
    local cloudUserRootDir=$(getConfig LFS_CI_CLOUD_USER_ROOT_DIR)
    mustHaveValue "${cloudUserRootDir}" "cloudUserRootDir"
    local cloudEsloc=$(getConfig LFS_CI_CLOUD_SLAVE_ESLOC)
    mustHaveValue "${cloudEsloc}" "cloudEsloc"
    local cloudEucarc=$(getConfig LFS_CI_CLOUD_SLAVE_EUCARC)
    mustHaveValue "${cloudEucarc}" "cloudEucarc"
    local cloudEmi=$(getConfig LFS_CI_CLOUD_SLAVE_EMI)
    mustHaveValue "${cloudEmi}" "cloudEmi"
    local cloudInstanceType=$(getConfig LFS_CI_CLOUD_SLAVE_INSTANCETYPE)
    mustHaveValue "${cloudInstanceType}" "cloudInstanceType"
    local cloudInstanceStartParams=$(getConfig LFS_CI_CLOUD_SLAVE_INST_START_PARAMS)
    mustHaveValue "${cloudInstanceStartParams}" "cloudInstanceStartParams"
    local cloudInstallScript=$(getConfig LFS_CI_CLOUD_SLAVE_INSTALL_SCRIPT)
    mustHaveValue "${cloudInstallScript}" "cloudInstallScript"

    # source seesetenv euca2ools=3.1.1. is already done via entry in linsee.cfg
    info Sourcing eucarc with: source ${cloudUserRootDir}/${cloudEucarc}
    execute source ${cloudUserRootDir}/${cloudEucarc}

    info Starting cloud instance with: execute export INST_START_PARAMS="${cloudInstanceStartParams}" ';' export HVM=1';' ${cloudLfs2Cloud} -c${cloudEsloc} -i${cloudEmi} -m${cloudInstanceType} -sLFS_CI -f${cloudInstallScript}
    export INST_START_PARAMS="${cloudInstanceStartParams}"
    export HVM=1
    local cloudStartLog=$(createTempFile)
    execute -l ${cloudStartLog} ${cloudLfs2Cloud} -c${cloudEsloc} -i${cloudEmi} -m${cloudInstanceType} -sLFS_CI -f${cloudInstallScript}

    local searchString='successfully started )'
    local cloudDnsName=$(grep "${searchString}" ${cloudStartLog} | cut -d\( -f2 | sed "s/${searchString}//" | sed "s/ //g")
    mustHaveValue "${cloudDnsName}" "cloudDnsName"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${cloudDnsName}"
    return 0
}

