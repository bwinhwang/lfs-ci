#!/bin/bash
## @file uc_developer_build.sh
#  @brief usecase for create a lfs developer build
#  @details  
#  namings: LFS_DEV_-_DEVELOPER_-_Build

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_special_build}   ]] && source ${LFS_CI_ROOT}/lib/special_build.sh
[[ -z ${LFS_CI_SOURCE_uc_lfs_package}  ]] && source ${LFS_CI_ROOT}/lib/uc_lfs_package.sh

usecase_LFS_DEVELOPER_BUILD() {
    requiredParameters DEVBUILD_LOCATION \
                       DEVBUILD_REVISION \
                       REQUESTOR_USERID 

    local currentDateTime=$(date +%Y%m%d-%H%M%S)
    local revision=${DEVBUILD_REVISION}
    local location=${DEVBUILD_LOCATION}
    local userid=${REQUESTOR_USERID^^}
    local label=$(printf "DEV_%s_%s_%s.%s" ${userid} ${location^^} ${revision} ${currentDateTime})
    mustHaveValue "${label}" "label"

    specialBuildPreparation DEV ${label} ${revision} ${location} 

    return
}

usecase_LFS_DEVELOPER_BUILD_PLATFORM() {
    requiredParameters WORKSPACE        \
                       UPSTREAM_PROJECT \
                       UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"

    # fakeing the branch name for workspace creation...
    local location=$(cat ${workspace}/bld/bld-fsmci-summary/location)
    mustHaveValue "${location}" "location"
    export LFS_CI_GLOBAL_BRANCH_NAME=${location}

    if ! specialBuildisRequiredForLrc ${location} ; then
        warning "build is not required."
        exit 0
    fi

    specialBuildCreateWorkspaceAndBuild

    info "build job finished."
    return
}

usecase_LFS_DEVELOPER_PACKAGE() {
    info "running usecase LFS package"
    ci_job_package

    info "developer build is done."
    return
}

