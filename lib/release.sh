#!/bin/bash
# @file  release.sh
# @brief release related functions

LFS_CI_SOURCE_release='$Id$'

[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_jenkins} ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh


## @fn      mustBePreparedForReleaseTask()
#  @brief   ensures, that the workspace is prepared for a release task
#  @details this function copy all required artifacts into the workspace and
#           set a log of variables, which are in use for the a release task
#  @param   <none>
#  @return  <none>
mustBePreparedForReleaseTask() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD \
                       JOB_NAME         BUILD_NUMBER

    info "upstream project is ${UPSTREAM_PROJECT} / ${UPSTREAM_PROJECT}"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHavePreparedWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    mustHaveNextCiLabelName
    local releaseLabel=$(getNextReleaseLabel)
    mustHaveValue "${releaseLabel}" "release label"

    local releaseDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_real_location)/${releaseLabel}
    mustExistDirectory ${releaseDirectory}
    info  "found release on share: ${releaseDirectory}"

     if [[ ! ${JOB_NAME} =~ summary$ ]] ; then
        storeEvent subrelease_started
        exit_add _releaseDatabaseEventSubReleaseFailedOrFinished
    fi

   # storing new and old label name into files for later use and archive
    execute mkdir -p ${workspace}/bld/bld-lfs-release/
    echo ${releaseLabel} > ${workspace}/bld/bld-lfs-release/label.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} \
            ${workspace}/bld/bld-lfs-release/label.txt

    local buildJobName=$(getBuildJobNameFromFingerprint)
    mustHaveValue "${buildJobName}" "build job name from fingerprint"
    local buildBuildNumber=$(getBuildBuildNumberFromFingerprint)
    mustHaveValue "${buildBuildNumber}" "build build name from fingerprint"

    info "based on build ${buildJobName} ${buildBuildNumber}"
    local requiredArtifacts=$(getConfig LFS_CI_prepare_workspace_required_artifacts)
    copyArtifactsToWorkspace ${buildJobName} ${buildBuildNumber} "${requiredArtifacts}"

    local releaseSummaryJobName=${JOB_NAME//${subJob}/summary}
    info "release job name is ${releaseSummaryJobName}"

    # TODO: demx2fk3 2015-08-04 FIXME we have to find the change log in the correct way.
    #                           Maybe we have to modify custom scm release script.
    local lastSuccessfulBuildDirectory=$(getBuildDirectoryOnMaster ${releaseSummaryJobName} lastSuccessfulBuild)
    if runOnMaster test -e ${lastSuccessfulBuildDirectory}/label.txt ; then
        copyFileFromBuildDirectoryToWorkspace ${releaseSummaryJobName} lastSuccessfulBuild label.txt
        execute mv ${WORKSPACE}/label.txt ${workspace}/bld/bld-lfs-release/oldLabel.txt
    else
        # TODO: demx2fk3 2014-08-08 this should be an error message.
        # TODO: demx2fk3 2015-08-04 should be retrieved from the database
        info "didn't get prev release. use based_on"
        local basedOn=$(getConfig LFS_PROD_uc_release_based_on)
        echo ${basedOn} > ${workspace}/bld/bld-lfs-release/oldLabel.txt
    fi

    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=$(cat ${workspace}/bld/bld-lfs-release/label.txt)
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME=$(cat ${workspace}/bld/bld-lfs-release/oldLabel.txt)
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL=${LFS_PROD_RELEASE_CURRENT_TAG_NAME//PS_LFS_OS_/PS_LFS_REL_}
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL=${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME//PS_LFS_OS_/PS_LFS_REL_}

    info "LFS os release ${LFS_PROD_RELEASE_CURRENT_TAG_NAME} is based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME}"
    info "LFS release ${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL} is based on ${LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL}"

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" \
        "<a href=https://wft.inside.nsn.com/ALL/builds/${releaseLabel}>${releaseLabel}</a><br>
         <a href=https://wft.inside.nsn.com/ALL/builds/${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}>${LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL}</a>"

    return
}

## @fn      _releaseDatabaseEventReleaseFailedOrFinished()
#  @brief   create a database entry for a failed or a finished release task
#  @details this function is called by the exit handler
#  @param   {rc}    exit code
#  @return  <none>
_releaseDatabaseEventReleaseFailedOrFinished() {
    if [[ ${1} -gt 0 ]] ; then
        storeEvent release_failed
    else
        storeEvent release_finished
    fi            
}

## @fn      _releaseDatabaseEventSubReleaseFailedOrFinished()
#  @brief   create a database entry for a failed or a finished sub release task
#  @details this function is called by the exit handler
#  @param   {rc}    exit code
#  @return  <none>
_releaseDatabaseEventSubReleaseFailedOrFinished() {
    if [[ ${1} -gt 0 ]] ; then
        storeEvent subrelease_failed
    else
        storeEvent subrelease_finished
    fi            
}

