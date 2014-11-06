#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_package}   ]] && source ${LFS_CI_ROOT}/lib/package.sh

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

    info "do nothing here, dummy task :), have a nice day"

    return 0
}

