#!/bin/bash

[[ -z ${LFS_CI_SOURCE_release} ]] && source ${LFS_CI_ROOT}/lib/release.sh

## @fn      extractArtifactsOnReleaseShare()
#  @brief   extract the artifacts of build job on the local workspace and copy the artifacts to the
#           /build share.
#  @details structure on the share is
#           bld-<ss>-<cfg>/<label>/results/...
#  @param   {jobName}      name of the job
#  @param   {buildNumber}  number of the build
#  @return  <none>
extractArtifactsOnReleaseShare() {

    requiredParameters LFS_PROD_RELEASE_PREVIOUS_TAG_NAME LFS_PROD_RELEASE_CURRENT_TAG_NAME

    mustBePreparedForReleaseTask

    local jobName=$(getBuildJobNameFromFingerprint)
    mustHaveValue "${jobName}" "build - job name from fingerprint"

    local buildNumber=$(getBuildBuildNumberFromFingerprint)
    mustHaveValue "${buildNumber}" "build - build number from fingerprint"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local labelName=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}
    mustHaveValue "${labelName}"

    copyArtifactsToWorkspace "${jobName}" "${buildNumber}"

    cd ${workspace}/bld/
    for dir in bld-*-* ; do
        [[ -d ${dir} ]] || continue
        local basename=$(basename ${dir})
        info "copy ${basename} to buildresults share ${basename}/${labelName}"
        _synchronizeBuildResultsToShare ${basename} ${basename/${labelName}
    done

    info "clean up workspace"
    execute rm -rf ${workspace}/bld

    return
}

_synchronizeBuildResultsToShare() {
    local basename=$1
    mustHaveValue "${basename}" "base name"

    local destination=$2
    mustHaveValue "${destination}" "destination location"

    local server=$(getConfig LINSEE_server)
    mustHaveValue "${server}" "linsee server host name"

    local resultBuildShare=$(getConfig LFS_PROD_UC_release_copy_build_to_share)
    mustHaveValue "${resultBuildShare}" "build result share"

    local canStoreArtifactsOnShare=$(getConfig LFS_CI_uc_release_can_store_build_results_on_share)
    if [[ ${canStoreArtifactsOnShare} ]] ; then
        execute -r 3 ssh ${server} chmod u+w ${resultBuildShare}/
        execute -r 3 ssh ${server} mkdir -p ${resultBuildShare}/${basename}/
        execute -r 3 ssh ${server} chmod u+w ${resultBuildShare}/${basename}/
        execute -r 3 ssh ${server} mkdir -p ${resultBuildShare}/${basename}/${destination}
        execute -r 3 rsync -av --exclude=.svn ${workspace}/bld/${basename}/. ${server}:${resultBuildShare}/${basename}/${destination}
        execute -r 3 ssh ${server} touch ${destination}
    else
        warning "storing artifacts on share is disabled in config"
    fi

    return
}
