#!/bin/bash
## @file uc_developer_build.sh
#  @brief usecase for create a lfs developer build
#  @details  
#  namings: 
#   - LFS_DEV_-_developer_-_Build
#   - LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fcmd
#   - LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fspc
#   - LFS_DEV_-_developer_-_Build_-_FSM-r3_-_qemu
#   - LFS_DEV_-_developer_-_Build_-_FSM-r3_-_fsm3_octeon2
#   - LFS_DEV_-_developer_-_Build_-_FSM-r3_-_qemu_64
#   - LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fsm4_k2
#   - LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fsm4_axm
#   - LFS_DEV_-_developer_-_Build_-_LRC_-_lcpa
#   - LFS_DEV_-_developer_-_Build_-_LRC_-_qemu
#   - LFS_DEV_-_developer_-_Package_-_package
#
# idea: developer build is quite the same as a knife build.
# The developer choose a revision and a branch (aka location) and provides also
# a patch file. With this information, this usecase creates a new production
#
# - INPUT
#   - name of the location
#   - revision number
#   - a patch file
# - OUTPUT
#   - a tarball on a share in Ulm.
#
# - Bugs / Limitations
#   - only on branches, which are compartible with the new ci
#   - there will be a problem, if developer choose a FSM-r4 location
#
# - Build Name: DEV_<USER>_<LOCATION>_<REVISION>_<UNIXTIMESTAMP>

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_special_build}   ]] && source ${LFS_CI_ROOT}/lib/special_build.sh
[[ -z ${LFS_CI_SOURCE_uc_lfs_package}  ]] && source ${LFS_CI_ROOT}/lib/uc_lfs_package.sh

## @fn      usecase_LFS_DEVELOPER_BUILD()
#  @brief   run the usecase developer build
#  @param   <none>
#  @return  <none>
usecase_LFS_DEVELOPER_BUILD() {
    requiredParameters DEVBUILD_LOCATION \
                       DEVBUILD_REVISION \
                       REQUESTOR_USERID 

    local currentDateTime=$(date +%s)
    local revision=${DEVBUILD_REVISION}
    local location=${DEVBUILD_LOCATION}
    local userid=${REQUESTOR_USERID^^}
    # label length must be less then 64 chars including kernel version (3.14.12)
    local label=$(printf "DEV_%s_%s_%s.%s" ${userid} ${location^^} ${revision} ${currentDateTime})
    mustHaveValue "${label}" "label"

    specialBuildPreparation DEV ${label} ${revision} ${location} 

    return
}

## @fn      usecase_LFS_DEVELOPER_BUILD_PLATFORM()
#  @brief   run the  usecase developer build for a platform
#  @param   <none>
#  @return  <none>
usecase_LFS_DEVELOPER_BUILD_PLATFORM() {
    requiredParameters WORKSPACE        \
                       UPSTREAM_PROJECT \
                       UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    mustHaveLocationForDeveloperBuild
    local location=${LFS_CI_GLOBAL_BRANCH_NAME}

    if ! specialBuildisRequiredForLrc ${location} ; then
        warning "build is not required."
        exit 0
    fi

    specialBuildCreateWorkspaceAndBuild

    info "build job finished."
    return
}

## @fn      usecase_LFS_DEVELOPER_PACKAGE()
#  @brief   run the usecase developer build - package
#  @param   <none>
#  @return  <none>
usecase_LFS_DEVELOPER_PACKAGE() {
    info "running usecase LFS package"

    mustHaveLocationForDeveloperBuild
    ci_job_package

    specialBuildUploadAndNotifyUser DEV

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    linkFileToArtifactsDirectory /build/home/${USER}/privateBuilds/${label}.tar.gz

    info "developer build is done."
    return
}

## @fn      mustHaveLocationForDeveloperBuild()
#  @brief   ensures, that there is a location for a developer build
#  @param   <none>
#  @return  <none>
mustHaveLocationForDeveloperBuild() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # we need to fake the branch for the layer below...
    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"

    # fakeing the branch name for workspace creation...
    local location=$(cat ${workspace}/bld/bld-fsmci-summary/location)
    mustHaveValue "${location}" "location"

    local subTaskName=$(getSubTaskNameFromJobName)
    mustHaveValue "${subTaskName}" "sub task name"

    if [[ ${subTaskName} = "FSM-r4" ]] ; then
        case ${location} in
            trunk)           location=FSM_R4_DEV ;;
            pronb-developer) location=FSM_R4_DEV ;;
            *)     # TODO: demx2fk3 2015-02-03 add check, if new location exists, otherwise no build
                   location=${location}_FSMR4 ;;
        esac
    fi
    mustHaveValue "${location}" "location"

    export LFS_CI_GLOBAL_BRANCH_NAME=${location}
    return
}