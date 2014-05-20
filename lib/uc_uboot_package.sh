#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      ci_job_package()
#  @brief   create a package from the build results for the testing / release process
#  @details copy all the artifacts from the sub jobs into the workspace and create the release structure
#  @todo    implement this
#  @param   <none>
#  @return  <none>
ci_job_package() {
    info "package the build results"

    # from Jenkins: there are some environment variables, which are pointing to the downstream jobs
    # which are execute within this jenkins jobs. So we collect the artifacts from those jobs
    # and untar them in the workspace directory.

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    debug "workspace is ${workspace}"

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}


    find ${workspace}

    copyReleaseCandidateToShare

    return 0
}

## @fn      copyReleaseCandidateToShare()
#  @brief   copy the release candidate to the build share
#  @details «full description»
#  @todo    «description of incomplete business»
#  @param   <none>
#  @return  <none>
copyReleaseCandidateToShare() {

# TODO: demx2fk3 2014-04-10 not working yet...

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue "${label}"
    
    local branch=$(getBranchName)
    mustHaveBranchName

    local localDirectory=${workspace}/upload
    local remoteDirectory=${lfsCiBuildsShare}/${branch}/data/${label}/os
    local oldRemoteDirectory=${lfsCiBuildsShare}/${branch}/data/$(ls ${lfsCiBuildsShare}/${branch}/data/ | tail -n 1 )
    local hardlink=""

    info "copy build results to ${remoteDirectory}"
    info "based on ${oldRemoteDirectory}"

    execute mkdir -p ${remoteDirectory}

    if [[ -d ${oldRemoteDirectory} ]] ; then
        hardlink="--link-dest=${oldRemoteDirectory}/os/"
    fi
    execute rsync -av --delete ${hardlink} ${localDirectory}/. ${remoteDirectory}

    # TODO: demx2fk3 2014-04-10 link sdks
    executeOnMaster ln -sf ${lfsCiBuildsShare}/${branch}/data/${label} ${lfsCiBuildsShare}/${branch}/${label}
    executeOnMaster ln -sf ${lfsCiBuildsShare}/${branch}/data/${label} ${lfsCiBuildsShare}/${branch}/trunk@${BUILD_NUMBER}
    executeOnMaster ln -sf ${lfsCiBuildsShare}/${branch}/data/${label} ${lfsCiBuildsShare}/${branch}/build_${BUILD_NUMBER}

    return
}

