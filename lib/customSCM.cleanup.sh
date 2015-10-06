#!/bin/bash

## @file    customSCM.cleanup.sh 
#  @brief   customSCM actions / functions for cleaning up the shares
#  @details see https://bts.inside.nokiasiemensnetworks.com/twiki/bin/view/MacPsWmp/CiInternals#The_CustomSCM_Plugin
#           In LFS, we have several shares, which must be cleaned up regularly. 
#           For this task, we have several admin cleanup jobs in Jenkins.
#           Every job is cleaning up a share on a site.

## @fn      actionCompare()
#  @brief   
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {
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
        phase_2_SC_LFS_in_Ulm)
            _scLfsOldReleasesOnBranches bld ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_2_SC_LFS_linuxkernel_in_Ulm)
            _scLfsOldReleasesOnBranches kernel ${tmpFileA}
            execute touch ${tmpFileB}
        ;;
        phase_3_*)
            fatal "not implemented"
        ;;
        phase_4_CI_LFS_in_*)
            _ciLfsRemoteSites ul ${tmpFileB}

            case ${subTaskName} in
                *_in_ou)  _ciLfsRemoteSites ou  ${tmpFileA} ;;
                *_in_wr)  _ciLfsRemoteSites wr  ${tmpFileA} ;;
                *_in_ch)  _ciLfsRemoteSites ch  ${tmpFileA} ;;
                *_in_es)  _ciLfsRemoteSites es  ${tmpFileA} ;;
                *_in_hz)  _ciLfsRemoteSites hz  ${tmpFileA} ;;
                *_in_be2) _ciLfsRemoteSites be2 ${tmpFileA} ;;
                *)       fatal "subTaskName ${subTaskName} not implemented" ;;
            esac
        ;;
        phase_4_SC_LFS_in_*)
            _scLfsRemoteSites ul kernel ${tmpFileB}
            _scLfsRemoteSites ul bld    ${tmpFileB}

            case ${subTaskName} in
                *_in_ou)    
                    _scLfsRemoteSites ou    kernel ${tmpFileA} 
                    _scLfsRemoteSites ou    bld    ${tmpFileA}
                ;;
                *_in_be)    
                    _scLfsRemoteSites be    kernel ${tmpFileA} 
                    _scLfsRemoteSites be    bld    ${tmpFileA}
                ;;
                *_in_be2)   
                    _scLfsRemoteSites be2   kernel ${tmpFileA} 
                    _scLfsRemoteSites be2   bld    ${tmpFileA} 
                ;;
                *_in_wr)    
                    _scLfsRemoteSites wr    kernel ${tmpFileA} 
                    _scLfsRemoteSites wr    bld    ${tmpFileA}
                ;;
                *_in_bh)    
                    _scLfsRemoteSites bh    kernel ${tmpFileA} 
                    _scLfsRemoteSites bh    bld    ${tmpFileA}
                ;;
                *_in_hz)    
                    _scLfsRemoteSites hz    kernel ${tmpFileA} 
                    _scLfsRemoteSites hz    bld    ${tmpFileA}
                ;;
                *_in_cloud) 
                    _scLfsRemoteSites cloud kernel ${tmpFileA} 
                    _scLfsRemoteSites cloud bld    ${tmpFileA}
                ;;
                *)  fatal "subTaskName ${subTaskName} not implemented" ;;
            esac
        ;;
        lfsArtifacts)
            _lfsArtifactsRemoveOldArtifacts ${tmpFileA}
        ;;
    esac

    # don't delete baselines, which are listed in the exclution list
    if [[ -e ${LFS_CI_ROOT}/etc/baselineExclutionList.sed ]] ; then
        info "removing removal canidates from list, which are excluded in baselineExclutionList.sed"
        execute sed -i -f ${LFS_CI_ROOT}/etc/baselineExclutionList.sed ${tmpFileA}
        rawDebug ${tmpFileA}
    fi

    # don't delete baselines, which are in the ECL
    copyFileFromBuildDirectoryToWorkspace "Admin_-_createLfsBaselineListFromEcl" "lastSuccessfulBuild" "archive/usedBaselinesInEcl.txt"
    local tmpFileC=$(createTempFile)
    debug "used baselines in ecl"
    rawDebug ${WORKSPACE}/usedBaselinesInEcl.txt

    execute -l ${tmpFileC} grep -vf ${WORKSPACE}/usedBaselinesInEcl.txt ${tmpFileA} 
    execute cp -f ${tmpFileC} ${tmpFileA}

    debug "tmpFile A"
    rawDebug ${tmpFileA}

    debug "tmpFile B"
    rawDebug ${tmpFileB}

    ${LFS_CI_ROOT}/bin/diffToChangelog.pl -d -a ${tmpFileA} -b ${tmpFileB} > ${CHANGELOG}

    debug "changelog"
    rawDebug ${CHANGELOG}

    # Fix empty changelogs:
    if [ ! -s "${CHANGELOG}" ] ; then
        echo -n "<log/>" >"${CHANGELOG}"
    fi

    return
}

## @fn      _ciLfsNotReleasedBuilds()
#  @brief   create a list of all not released builds on CI_LFS share
#  @param   {resultFile}    name of the result file
#  @return  <none>
_ciLfsNotReleasedBuilds() {

    # format of the result file is
    # <time stamp> <pathName>
    local resultFile=$1

    # TODO: demx2fk3 2014-07-28 cleanup

    # TODO: demx2fk3 2015-07-30 replace with getconfig
    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates
    # TODO: demx2fk3 2015-07-30 replace with getconfig
    local rcVersions=/build/home/CI_LFS/RCversion/os

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    local tmpFile=$(createTempFile)

    # TODO: demx2fk3 2015-07-30 replace with getconfig
    local retentionTime=4

    for link in ${rcVersions}/* ; do
        echo test ${link}
        [[ ! -L ${link}     ]] && continue 
        [[ ${link} =~ -ci   ]] && continue
        [[ ${link} =~ trunk ]] && continue
        echo ${link} ok
        readlink -f ${link} >> ${tmpFile}
    done

    sort -u ${tmpFile} > ${tmpFileA}
    find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +${retentionTime} -type d -printf "%p\n" | sort -u > ${tmpFileB}

    debug "list from find"
    rawDebug ${tmpFileB}
    debug "list from rcVersions"
    rawDebug ${tmpFileA}

    grep -v -f ${tmpFileA} ${tmpFileB} | sed "s/^/1 /g"    \
        > ${resultFile}

    rawDebug ${resultFile}

    return
}

## @fn      _scLfsOldReleasesOnBranches()
#  @brief   create a list of all old releases on all branches from SC_LFS share (> 60 days)
#  @param   {shareType}   type of the share (e.g. bld, kernel, ...)
#  @param   {resultFile}    file which contains the results
#  @return  <none>
_scLfsOldReleasesOnBranches() {
    local shareType=$1
    local resultFile=$2

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)

    local directoryToCleanup=$(getConfig ADMIN_sync_share_remote_directoryName -t siteName:ul -t shareType:${shareType})
    mustExistDirectory ${directoryToCleanup}

    local days=$(getConfig ADMIN_sync_share_retention_in_days -t shareType:${shareType})
    mustHaveValue "${days}" "retention in days"

    local depth=$(getConfig ADMIN_sync_share_check_depth -t shareType:${shareType})
    mustHaveValue "${depth}" "depth to check in the filesystem (for find)"

    info "check for baselines older than ${days} days in ${directoryToCleanup}"
    execute -l ${tmpFileA}   find ${directoryToCleanup} -mindepth ${depth} -maxdepth ${depth} -mtime +${days} -type d -printf "%p\n" 

    execute -l ${tmpFileA}   sort -u ${tmpFileA} 
    cat ${tmpFileA} |  ${LFS_CI_ROOT}/bin/removalCandidates.pl  > ${tmpFileB}
    execute -l ${resultFile} grep -w -f ${tmpFileB} ${tmpFileA} 
    execute                  sed -i -e "s/^/1 /g" ${resultFile}

    return 0
}

## @fn      _ciLfsRemoteSites()
#  @brief   create a list of all releases in CI_LFS on a remove site
#  @param   {siteName}    name of the site (two letters)
#  @param   {resultFile}  file which contains the results  
#  @return  <none>
_ciLfsRemoteSites() {
    local siteName=$1
    local resultFile=$2

    export siteName
    # TODO: demx2fk3 2015-07-30 replace with getconfig
    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates/
    local find=$(getConfig ADMIN_sync_share_find_command)

    info "directoryToCleanup is ${directoryToCleanup}"
    ssh ${siteName}sync "${find} ${directoryToCleanup} -mindepth 2 -maxdepth 2 -type d -printf \"1 %p\n\" " \
        | sort -u > ${resultFile} 
    mustBeSuccessfull "$?" "ssh find ${siteName}"

    return
}

## @fn      _scLfsRemoteSites()
#  @brief   create a list of all releases in SC_LFS on a remove site
#  @param   {siteName}    name of the site (two letters)
#  @param   {shareType}   type of the share (e.g. bld, kernel, ...)
#  @param   {resultFile}  file which contains the results  
#  @return  <none>
_scLfsRemoteSites() {
    local siteName=$1
    local shareType=$2
    local resultFile=$3

    local directoryToCleanup=$(getConfig ADMIN_sync_share_remote_directoryName -t siteName:${siteName} -t shareType:${shareType})
    local find=$(getConfig ADMIN_sync_share_find_command -t siteName:${siteName} -t shareType:${shareType})

    info "directoryToCleanup is ${directoryToCleanup}"
    ssh ${siteName}sync "${find} ${directoryToCleanup} -mindepth 2 -maxdepth 2 -type d -printf \"1 %p\n\" " \
        | sort -u >> ${resultFile} 
    mustBeSuccessfull "$?" "ssh find ${siteName}"

    debug "direactories to cleanup in ${siteName} ${shareType}"
    rawDebug ${resultFile}

    return
}

## @fn      _ciLfsOldReleasesOnBranches()
#  @brief   create a list of all old releases on all branches in CI_LFS share (> 60 days)
#  @param   {resultFile}    file which contains the results
#  @param   {«parameter name»}    «parameter description»
#  @return  <none>
_ciLfsOldReleasesOnBranches() {
    local resultFile=$1

    local tmpFileA=$(createTempFile)
    local tmpFileB=$(createTempFile)
    # TODO: demx2fk3 2015-07-30 replace this with getConfig
    local directoryToCleanup=/build/home/CI_LFS/Release_Candidates/
    # TODO: demx2fk3 2015-07-30 replace this with getConfig
    local retentionTime=60

    find ${directoryToCleanup} -mindepth 2 -maxdepth 2 -mtime +${retentionTime} -type d -printf "%p\n" \
        | sort -u > ${tmpFileA}

    ${LFS_CI_ROOT}/bin/removalCandidates.pl  < ${tmpFileA} > ${tmpFileB}
    grep -w -f ${tmpFileB} ${tmpFileA} | sed "s/^/1 /g" > ${resultFile}

    return
}


## @fn      _lfsArtifactsRemoveOldArtifacts()
#  @brief   create a list of all old artifacts on the artifacts share (> 5 days)
#  @param   {resultFile}    file which contains the results
#  @return  <none>
_lfsArtifactsRemoveOldArtifacts() {
    local resultFile=$1

    local directoryToCleanup=$(getConfig artifactesShare)
    # TODO: demx2fk3 2015-07-30 replace this with getConfig
    local retentionTime=5

    for jobName in ${directoryToCleanup}/* 
    do 
        [[ -d ${jobName} ]] || continue
        info "checking for artifacts for ${jobName}"
        find ${jobName} -mindepth 1 -maxdepth 1 -ctime +${retentionTime} -type d -printf "%C@ %p\n" \
            | sort -n     \
            | tac         \
            | tail -n +10 \
            >> ${resultFile}
    done

    return
}

## @fn      actionCalculate()
#  @brief   calculate command for custom SCM
#  @param   <none>
#  @return  <none>
actionCalculate() {
    touch ${REVISION_STATE_FILE}
    return 
}

