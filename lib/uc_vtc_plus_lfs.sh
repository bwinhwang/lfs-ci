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

    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${labelName}
    mustExistDirectory ${releaseDirectory}
    debug "found results of package job on share: ${labelName}"

    info "adding files from VCF to transferlist"
    execute -n ${LFS_CI_ROOT}/bin/xpath -q -e '/versionControllFile/file/@source' ${releaseDirectory}/os/version_control.xml | \
        cut -d'"' -f 2 | sed "s:^:os/:" > ${workspace}/filelist_to_sync

    local listToSync=$(getConfig LFS_CI_uc_vtc_plus_lfs_files_to_sync)
    echo 'os/version_control.xml' >> ${workspace}/filelist_to_sync
    echo ${listToSync} >> ${workspace}/filelist_to_sync

    rawDebug ${workspace}/filelist_to_sync

    local remoteServer=$(getConfig LFS_CI_uc_vtc_plus_lfs_remote_server)
    mustHaveValue "${remoteServer}" "remote server name"

    local remotePath=$(getConfig LFS_CI_uc_vtc_plus_lfs_remote_path)
    mustHaveValue "${remotePath}" "remote path name"

    execute rsync --archive                                   \
                  --verbose                                   \
                  --recursive                                 \
                  --partial --progress                        \
                  --rsh=ssh                                   \
                  --files-from=${workspace}/filelist_to_sync  \
                  ${releaseDirectory}                         \
                  ${remoteServer}:${remotePath}

    info "sync done of ${labelName} for VTC+LFS"

    return
}
