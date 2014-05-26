#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh
source ${LFS_CI_ROOT}/lib/package.sh

## @fn      ci_job_package()
#  @brief   create a package from the build results for the testing / release process
#  @details copy all the artifacts from the sub jobs into the workspace and create the release structure
#  @param   <none>
#  @return  <none>
ci_job_package() {
    info "package the build results"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace
    mustHaveWritableWorkspace

    debug "workspace is ${workspace}"

    copyArtifactsToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD}

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"
    info "label name is ${label}"

    local localDirectory=${workspace}/upload
    execute mkdir -p ${localDirectory}

    find ${workspace}

    for bldDirectory in ${workspace}/bld/bld-*brm*-* ; do
        info "bldDirectory is ${bldDirectory}"
        [[ -d ${bldDirectory} ]] || continue

        info "copy uboot for ${bldDirectory}..."

        local srcDirectory=${bldDirectory}/results
        local dstDirectory=${workspace}/upload/bld/${bldDirectory}/results

        execute mkdir -p ${dstDirectory}
        execute rsync -av ${srcDirectory}/. ${dstDirectory}/

    done

    copyReleaseCandidateToShare

    return 0
}

