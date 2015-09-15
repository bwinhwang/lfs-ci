#!/bin/bash
#  @file  uc_vtc_plus_lfs.sh
#  @brief usecases vtc plus lfs

[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      usecase_VTC_PLUS_LFS_SYNC_PRODUCTION()
#  @brief   copy the build artifacts of the production from ulm to bangalore
#  @param   <none>
#  @return  <none>
usecase_VTC_PLUS_LFS_SYNC_PRODUCTION() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHavePreparedWorkspace

    mustHaveNextCiLabelName
    local labelName=$(getNextCiLabelName)

    _setBuildDescriptionForVtc

    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${labelName}
    mustExistDirectory ${releaseDirectory}
    debug "found results of package job on share: ${labelName}"

    info "adding files from VCF to transferlist"
    execute -n xpath -q -e '/versionControllFile/file/@source' ${releaseDirectory}/os/version_control.xml | \
        cut -d'"' -f 2 | sed "s:^:os/:" > ${workspace}/filelist_to_sync

    local listToSync=$(getConfig LFS_CI_uc_vtc_plus_lfs_files_to_sync)
    echo 'os/version_control.xml' >> ${workspace}/filelist_to_sync
    for file in ${listToSync} ; do
        echo ${file} >> ${workspace}/filelist_to_sync
    done

    rawDebug ${workspace}/filelist_to_sync

    local remoteServer=$(getConfig LFS_CI_uc_vtc_plus_lfs_remote_server)
    mustHaveValue "${remoteServer}" "remote server name"

    local remotePath=$(getConfig LFS_CI_uc_vtc_plus_lfs_remote_path)
    mustHaveValue "${remotePath}" "remote path name"

    info "starting sync..."
    execute rsync --archive                                   \
                  --verbose                                   \
                  --recursive                                 \
                  --partial --progress                        \
                  --rsh=ssh                                   \
                  --files-from=${workspace}/filelist_to_sync  \
                  ${releaseDirectory}                         \
                  ${remoteServer}:${remotePath}/${labelName}

    info "sync done of ${labelName} for VTC+LFS"

    echo "DELIVERY_DIRECTORY=${releaseDirectory}" > ${workspace}/env.txt

    return 0
}


## @fn      _setBuildDescriptionForVtc()
#  @brief   set the build description for the vtc test job
#  @param   <none>
#  @return  <none>
_setBuildDescriptionForVtc() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local fsmr4BuildJobName=$(getJobJobNameFromFingerprint 'Build_-_FSM-r4_-_fsm4_axm$')
    mustHaveValue "${fsmr4BuildJobName}" "job name of fsm-r4 axm build job"

    local fsmr4BuildBuildNumber=$(getJobBuildNumberFromFingerprint 'Build_-_FSM-r4_-_fsm4_axm$')
    mustHaveValue "${fsmr4BuildBuildNumber}" "build number of fsm-r4 axm build job"

    local tmpFile=${workspace}/tempFile
    copyAndExtractBuildArtifactsFromProject ${fsmr4BuildJobName} ${fsmr4BuildBuildNumber}

    local labelName=$(getNextCiLabelName)

    echo ${labelName} > ${tmpFile}
    execute -n cut -d= -f2- ${workspace}/bld/bld-externalComponents-summary/externalComponents | sort -u >> ${tmpFile}

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "$(sed 's/$/<br>/g' ${tmpFile} )"

    return 0
}
