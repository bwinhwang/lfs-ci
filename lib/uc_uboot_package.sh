#!/bin/bash
## @file  uc_uboot_package.sh
#  @brief the uboot packaging usecase

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_package}   ]] && source ${LFS_CI_ROOT}/lib/package.sh
[[ -z ${LFS_CI_SOURCE_database}  ]] && source ${LFS_CI_ROOT}/lib/database.sh

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

    databaseEventBuildFinished

    local localDirectory=${workspace}/upload
    execute mkdir -p ${localDirectory}

    for bldDirectory in ${workspace}/bld/bld-*brm*-* ; do
        info "bldDirectory is ${bldDirectory}"
        [[ -d ${bldDirectory} ]] || continue
        local baseNameBldDir=$(basename ${bldDirectory})

        info "copy uboot for ${bldDirectory}..."

        local srcDirectory=${bldDirectory}
        local dstDirectory=${workspace}/upload/bld/${baseNameBldDir}

        execute mkdir -p ${dstDirectory}
        execute rsync -av --delete ${srcDirectory}/. ${dstDirectory}/

    done

    copyReleaseCandidateToShare

    return 0
}

