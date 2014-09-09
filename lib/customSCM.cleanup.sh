#!/bin/bash

## @fn      actionCompare()
#  @brief   
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {
    info "always triggering a build..."
    exit 1
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

    info "subtask name is ${subTaskName}"

    case ${subTaskName} in 
        phase_1_CI_LFS_in_Ulm)
            _ciLfsNotReleasedBuilds ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_2_CI_LFS_in_Ulm)
            _ciLfsOldReleasesOnBranches ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_3_CI_LFS_in_Ulm)
            fatal "not implemented"
        ;;
        phase_2_SC_LFS_linuxKernel_in_Ulm)
            _scLfsLinuxKernelOldReleasesOnBranches ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_2_SC_LFS_in_Ulm)
            _scLfsOldReleasesOnBranches ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_3_SC_LFS_in_Ulm)
            fatal "not implemented"
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
        lfsArtifacts)
            _lfsArtifactsRemoveOldArtifacts ${tmpFileA}
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
    local resultFile=$1

    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates
    local rcVersions=/build/home/CI_LFS/RCversion/os

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    local tmpFile=$(createTempFile)

    
    for link in ${rcVersions}/* ; do
        # we are skiping all entries, which are not a link, contains trunk and -ci
        [[ ! -L ${link}     ]] && continue 
        [[ ${link} =~ -ci   ]] && continue
        [[ ${link} =~ trunk ]] && continue
        execute -n readlink -f ${link} >> ${tmpFile}
    done

    # release candidates, which are older than 60 days and are not released
    execute -n sort -u ${tmpFile} > ${tmpFileA}
    execute -n find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +7 -type d -printf "%p\n" \
        | execute -n sort -u > ${tmpFileB}
    execute -n grep -v -f ${tmpFileA} ${tmpFileB} \
        | execute -n sed "s/^/1 /g" > ${resultFile}

    return
}

_scLfsOldReleasesOnBranches() {
    # CUSTOM_SCM_cleanup_find_max_depth       = 2
    # CUSTOM_SCM_cleanup_find_min_depth       = 2
    # CUSTOM_SCM_cleanup_baseline_age         = 60
    # CUSTOM_SCM_cleanup_directory_to_cleanup = /build/home/SC_LFS/releases/bld

    local resultFile=$1
    _genericOldReleasesOnBranch ${resultFile}
    return
}

_scLfsLinuxKernelOldReleasesOnBranches() {
    # CUSTOM_SCM_cleanup_find_max_depth       = 1
    # CUSTOM_SCM_cleanup_find_min_depth       = 1
    # CUSTOM_SCM_cleanup_baseline_age         = 1500
    # CUSTOM_SCM_cleanup_directory_to_cleanup = /build/home/SC_LFS/linuxkernels

    local resultFile=$1
    _genericOldReleasesOnBranch ${resultFile}
    return
}

_ciLfsRemoteSites() {
    # CUSTOM_SCM_cleanup_find_max_depth = 2
    # CUSTOM_SCM_cleanup_find_min_depth = 2
    # ADMIN_sync_share_remote_directoryName = /build/home/CI_LFS/Release_Candidates/
    local siteName=$1
    local resultFile=$2
    _genericRemoteSites ${siteName} ${resultFile}
    return
}

_scLfsRemoteSites() {
    # CUSTOM_SCM_cleanup_find_max_depth = 2
    # CUSTOM_SCM_cleanup_find_min_depth = 2

    local siteName=$1
    local resultFile=$2
    _genericRemoteSites ${siteName} ${resultFile}
    return
}

_ciLfsOldReleasesOnBranches() {
    # CUSTOM_SCM_cleanup_find_max_depth       = 2
    # CUSTOM_SCM_cleanup_find_min_depth       = 2
    # CUSTOM_SCM_cleanup_baseline_age         = 60
    # CUSTOM_SCM_cleanup_directory_to_cleanup = /build/home/CI_LFS/Release_Candidates

    local resultFile=$1
    _genericOldReleasesOnBranch ${resultFile}
    return
}

_lfsArtifactsRemoveOldArtifacts() {
    local resultFile=$1
    local directoryToCleanup=/build/home/psulm/LFS_internal/artifacts

    for jobName in ${directoryToCleanup}/* 
    do 
        [[ -d ${jobName} ]] || continue
        info "checking for artifacts for ${jobName}"
        find ${jobName} -mindepth 1 -maxdepth 1 -ctime +10 -type d -printf "%C@ %p\n" \
            | sort -n     \
            | tac         \
            | tail -n +10 \
            >> ${resultFile}
    done

    return
}

_lfsCiLogfiles() {
    local resultFile=$1
    find /ps/lfs/ci/log/ -type f -ctime +60 | sed "s:^:1 :" > ${resultFile}
    return
}

_genericRemoteSites() {
    local siteName=$1
    local resultFile=$2

    export siteName

    local directoryToCleanup=$(getConfig ADMIN_sync_share_remote_directoryName)
    local find=$(getConfig ADMIN_sync_share_find_command)
    local maxdepth=$(getConfig CUSTOM_SCM_cleanup_find_max_depth)
    local mindepth=$(getConfig CUSTOM_SCM_cleanup_find_min_depth)

    info "directoryToCleanup is ${directoryToCleanup}"
    execute -n ssh ${siteName}sync "${find} ${directoryToCleanup} -mindepth ${mindepth} -maxdepth ${maxdepth} -type d -printf \"1 %p\n\" " \
        | execute -n sort -u > ${resultFile} 

    return
}

_genericOldReleasesOnBranch() {
    local resultFile=$1
    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    local directoryToCleanup=$(getConfig CUSTOM_SCM_cleanup_directory_to_cleanup)
    local days=$(getConfig CUSTOM_SCM_cleanup_baseline_age)
    local mindepth=$(getConfig CUSTOM_SCM_cleanup_find_min_depth)
    local maxdepth=$(getConfig CUSTOM_SCM_cleanup_find_max_depth)

    info "check for baselines older than ${days} days in ${directoryToCleanup}"
    execute -n find ${directoryToCleanup} \
                    -mindepth ${mindepth} \
                    -maxdepth ${maxdepth} \
                    -mtime +${days}       \
                    -type d               \
                    -printf "%p\n"        \
        | execute -n sort -u > ${tmpFileA}

    execute -n ${LFS_CI_ROOT}/bin/removalCanidates.pl  < ${tmpFileA} > ${tmpFileB}
    execute -n grep -w -f ${tmpFileB} ${tmpFileA} \
        | execute -n sed "s/^/1 /g" > ${resultFile}

    return
}

