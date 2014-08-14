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
        phase_1_CI_LFS_in_Ulm)
            _ciLfsNotReleasedBuilds ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_2_CI_LFS_in_Ulm)
            _ciLfsOldReleasesOnBranches ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_3_SC_LFS_in_Ulm)
            fatal "not implemented"
        ;;
        phase_3_CI_LFS_in_Ulm)
            fatal "not implemented"
        ;;
        phase_2_SC_LFS_in_Ulm)
            _scLfsOldReleasesOnBranches ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_4_CI_LFS_in_*)
            _ciLfsRemoteSites ul ${tmpFileB}

            case ${subTaskName} in
                *_in_ou) _ciLfsRemoteSites ou ${tmpFileA} ;;
                *_in_wr) _ciLfsRemoteSites wr ${tmpFileA} ;;
                *_in_ch) _ciLfsRemoteSites ch ${tmpFileA} ;;
                *_in_es) _ciLfsRemoteSites es ${tmpFileA} ;;
                *)       fatal "subTaskName ${subTaskName} not implemented" ;;
            esac
        ;;
        phase_4_SC_LFS_in_*)
            _scLfsRemoteSites ul ${tmpFileB}

            case ${subTaskName} in
                *_in_ou) _scLfsRemoteSites ou ${tmpFileA} ;;
                *_in_wr) _scLfsRemoteSites wr ${tmpFileA} ;;
                *_in_bh) _scLfsRemoteSites bh ${tmpFileA} ;;
                *_in_du) 
                    execute sed -i "s:/build/home/SC_LFS/releases/bld:/usrd9/build/home/SC_LFS/releases/bld:g" ${tmpFileB}
                    _scLfsRemoteSites du ${tmpFileA} 
                ;;
                *) exit 1 ;;
            esac

        ;;
    esac

    if [[ -e ${LFS_CI_ROOT}/etc/baselineExclutionList.sed ]] ; then
        execute sed -i -f ${LFS_CI_ROOT}/etc/baselineExclutionList.sed ${tmpFileA}
    fi

    ${LFS_CI_ROOT}/bin/diffToChangelog.pl -d -a ${tmpFileA} -b ${tmpFileB} > ${CHANGELOG}

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
    find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +7 -type d -printf "%p\n" | sort -u > ${tmpFileB}

#        |  egrep -e 'PS_LFS_OS_[0-9]{4}_[0-9]{2}_[0-9]{4}' \
    # release candidates, which are older than 60 days and are not released
    grep -v -f ${tmpFileA} ${tmpFileB} | sed "s/^/1 /g"    \
        > ${resultFile}

    return
}

_scLfsOldReleasesOnBranches() {
    local resultFile=$1
    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    local directoryToCleanup=/build/home/SC_LFS/releases/bld/
    local days=900

    info "check for baselines older than ${days} days in ${directoryToCleanup}"
    find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +${days} -type d -printf "%p\n" \
        | sort -u > ${tmpFileA}

    ${LFS_CI_ROOT}/bin/removalCanidates.pl  < ${tmpFileA} > ${tmpFileB}

    grep -w -f ${tmpFileB} ${tmpFileA} | sed "s/^/1 /g" > ${resultFile}

    return
}

_ciLfsRemoteSites() {
    local siteName=$1
    local resultFile=$2

    export siteName
    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates/
    local find=$(getConfig ADMIN_sync_share_find_command)

    info "directoryToCleanup is ${directoryToCleanup}"
    ssh ${siteName}sync "${find} ${directoryToCleanup} -mindepth 2 -maxdepth 2 -type d -printf \"1 %p\n\" " \
        | sort -u > ${resultFile} 
    mustBeSuccessfull "$?" "ssh find ${siteName}"

    return
}
_scLfsRemoteSites() {
    local siteName=$1
    local resultFile=$2

    export siteName
    export shareType=bld
    local directoryToCleanup=$(getConfig ADMIN_sync_share_remote_directoryName)
    local find=$(getConfig ADMIN_sync_share_find_command)

    info "directoryToCleanup is ${directoryToCleanup}"
    ssh ${siteName}sync "${find} ${directoryToCleanup} -mindepth 2 -maxdepth 2 -type d -printf \"1 %p\n\" " \
        | sort -u > ${resultFile} 
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

