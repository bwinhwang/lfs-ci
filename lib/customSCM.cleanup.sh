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

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)

    # TODO: demx2fk3 2014-07-28 cleanup

    local subTaskName=$(getSubTaskNameFromJobName)

    case ${subTaskName} in 
        CI_LFS_in_Ulm_Phase_1)
            _ciLfsNotReleasedBuilds ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        CI_LFS_in_Ulm_Phase_2)
            _ciLfsOldReleasesOnBranches ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        CI_LFS_in_Ulm_Phase_3)
        ;;
        SC_LFS_in_Ulm_Phase_2)
            _scLfsOldReleasesOnBranches ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        SC_LFS_in_*_Phase_4)
            case ${subTaskName} in
                *Oulu*)    _scLfsRemoteSites ousync ${tmpFileA} ;;
                *Wrozlaw*) _scLfsRemoteSites wrsync ${tmpFileA} ;;
                *Ulm*)     _scLfsRemoteSites ulsync ${tmpFileA} ;;
            esac

            _scLfsRemoteSites ulsync ${tmpFileB}
        ;;
    esac

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

_ciLfsNotReleasedBuilds() {

    # format of the result file is
    # <time stamp> <pathName>
    local resultFile=$1

    # TODO: demx2fk3 2014-07-28 cleanup

    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates
    local rcVersions=/build/home/CI_LFS/RCversion/os

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    local tmpFile=$(createTempFile)

    for link in ${rcVersions}/* ; do
        echo test ${link}
        [[ ! -L ${link}     ]] && continue 
        [[ ${link} =~ -ci   ]] && continue
        [[ ${link} =~ trunk ]] && continue
        echo ${link} ok
        readlink -f ${link} >> ${tmpFile}
    done

    sort -u ${tmpFile} > ${tmpFileA}
    find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +60 -type d -printf "%p\n" | sort -u > ${tmpFileB}

    # release candidates, which are older than 60 days and are not released
    grep -v -f ${tmpFileA} ${tmpFileB} | sed "s/^/1 /g" > ${resultFile}

    return
}

_scLfsOldReleasesOnBranches() {
    local resultFile=$1
    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    local directoryToCleanup=/build/home/SC_LFS/releases/bld/
    local days=1400

    info "check for baselines older than ${days} days in ${directoryToCleanup}"
    find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +${days} -type d -printf "%p\n" \
        | sort -u > ${tmpFileA}

    ${LFS_CI_ROOT}/bin/removalCanidates.pl  < ${tmpFileA} > ${tmpFileB}

    grep -f ${tmpFileB} ${tmpFileA} | sed "s/^/1 /g" > ${resultFile}

    return
}

_scLfsRemoteSites() {
    local resultFile=$2
    local siteName=$1
    local directoryToCleanup=/build/home/SC_LFS/releases/bld/

    ssh ${siteName} "find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -type d -printf \"1 %p\n\" " | sort -u > ${resultFile} 
    mustBeSuccessfull "$?" "ssh find ${siteName}"

    return
}

_ciLfsOldReleasesOnBranches() {
    local resultFile=$1

    local tmpFileA=$(createTempFile)
    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates

    find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +60 -type d -printf "%p\n" \
        | sort -u \
        | ${LFS_CI_ROOT}/bin/removalCanidates.pl \
        | sed "s/^/1 ${directoryToCleanup}/g" | sort -u > ${resultFile}

    return
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details «full description»
#  @param   <none>
#  @return  <none>
actionCalculate() {
    touch ${REVISION_STATE_FILE}
    return 
}

