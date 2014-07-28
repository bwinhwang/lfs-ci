#!/bin/bash

## @fn      actionCompare()
#  @brief   
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {

#     if [[ -z "${REVISION_STATE_FILE}" ]] ; then
#         info "no old revision state file found"
#         exit 0
#     fi
# 
#     export subTaskName=$(getSubTaskNameFromJobName)
#     # syntax is <share>_to_<site>
#     export shareType=$(cut -d_ -f 1 <<< ${subTaskName})
#     export siteName=$(cut -d_ -f 3 <<< ${subTaskName})
#     local directoryNameToSynchronize=$(getConfig ADMIN_sync_share_local_directoryName)
#     local findDepth=$(getConfig ADMIN_sync_share_check_depth)
#     unset shareType siteName
# 
#     # remove this
#     if [[ -z ${findDepth} ]] ; then
#         findDepth=1
#     fi
#     # read the revision state file
#     # format:
#     # projectName
#     # buildNumber
#     { read oldDirectoryNameToSynchronize ; 
#       read oldChecksum ; } < "${REVISION_STATE_FILE}"
# 
#     info "old revision state data are ${oldDirectoryNameToSynchronize} / ${oldChecksum}"
# 
#     # comparing to new state
#     if [[ "${directoryNameToSynchronize}" != "${oldDirectoryNameToSynchronize}" ]] ; then
#         info "directory name changed, trigger build"
#         exit 0
#     fi
# 
#     local checksum=$(find ${directoryNameToSynchronize} -mindepth ${findDepth} -maxdepth ${findDepth} -printf "%C@ %p\n" | sort | md5sum | cut -d" " -f 1)
# 
#     info "new revision state data are ${directoryNameToSynchronize} / ${checksum}"
# 
#     if [[ "${checksum}" != "${oldChecksum}" ]] ; then
#         info "checksum has changed, trigger build"
#         exit 0
#     fi
# 
    info "no change in ${directoryNameToSynchronize} / ${checksum}"
    exit 1
}


## @fn      actionCheckout()
#  @brief   action which is called by custom scm jenkins plugin to create or update a workspace and create the changelog
#  @details the create workspace task is empty here. We just calculate the changelog
#  @param   <none>
#  @return  <none>
actionCheckout() {
    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"

#     export subTaskName=$(getSubTaskNameFromJobName)
#     # syntax is <share>_to_<site>
#     export shareType=$(cut -d_ -f 1 <<< ${subTaskName})
#     export siteName=$(cut -d_ -f 3 <<< ${subTaskName})
#     local directoryNameToSynchronize=$(getConfig ADMIN_sync_share_local_directoryName)
#     local findDepth=$(getConfig ADMIN_sync_share_check_depth)
#     unset shareType siteName
#     # remove this
#     if [[ -z ${findDepth} ]] ; then
#         findDepth=1
#     fi
# 
#     local oldFileListing=$(createTempFile)
#     local newFileListing=$(createTempFile)

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)

    # TODO: demx2fk3 2014-07-28 cleanup

    _notReleasedBuilds ${tmpFileA}
    execute touch ${tmpFileB}

    if [[ -e ${LFS_CI_ROOT}/etc/baselineExclutionList.sed ]] ; then
        execute sed -i -f ${LFS_CI_ROOT}/etc/baselineExclutionList.sed ${tmpFileA}
    fi

    ${LFS_CI_ROOT}/bin/diffToChangelog.pl -a ${tmpFileA} -b ${tmpFileB} > ${CHANGELOG}

    # Fix empty changelogs:
    if [ ! -s "${CHANGELOG}" ] ; then
        echo -n "<log/>" >"${CHANGELOG}"
    fi

    return
}

_notReleasedBuilds() {

    # format of the result file is
    # <time stamp> <pathName>
    local resultFile=$1

    # TODO: demx2fk3 2014-07-28 cleanup

    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates
    local rcVersions=/build/home/CI_LFS/RCversion/os/

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    local tmpFile=$(createTempFile)

    for link in ${rcVersions}/* ; do
        [[ -L ${link} ]] || continue 
        readlink -f ${link} >> ${tmpFile}
    done

    sort ${tmpFile} > ${tmpFileA}
    find ${directoryToCleanup} -maxdepth 2 -mtime +60 -type d -printf "%p\n" | sort > ${tmpFileB}

    # release candidates, which are older than 60 days and are not released
    diff ${tmpFileA} ${tmpFileB} | grep "^<" | sed "s/^./1/" > ${resultFile}

    return
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details «full description»
#  @param   <none>
#  @return  <none>
actionCalculate() {
    return 
}

