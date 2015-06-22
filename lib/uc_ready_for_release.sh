#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      usecase_LFS_READY_FOR_RELEASE()
#  @brief   run usecase LFS_READY_FOR_RELEASE
#  @details the usecase LFS_READY_FOR_RELEASE is just a dummy task. 
#           It's copying the nesessery files and creating a symlink to trigger
#           the sync of the release to the different shares / sites
#  @param   <none>
#  @return  <none>
usecase_LFS_READY_FOR_RELEASE() {

    mustHaveCleanWorkspace

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD \
                       JOB_NAME BUILD_NUMBER

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"
    createArtifactArchive

    copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fingerprint.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME}         ${BUILD_NUMBER}   ${WORKSPACE}/fingerprint.txt

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    createReleaseLinkOnCiLfsShare ${labelName}

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${label}"

    return
}

## @fn      createReleaseLinkOnCiLfsShare()
#  @brief   create a link in CI_LFS to trigger the sync to remote sites
#  @param   {labelName}    name of the production
#  @return  <none>
createReleaseLinkOnCiLfsShare() {
    local labelName=$1
    mustHaveValue "${labelName}" "label name"

    local linkDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_link_location)
    mustExistDirectory ${linkDirectory}

    local pathToLink=../../$(getConfig LFS_CI_UC_package_copy_to_share_path_name)/${labelName}
    local relTagName=${labelName//PS_LFS_OS_/PS_LFS_REL_}
    info "creating link in CI_LFS RCversion ${relTagName}"
    execute mkdir -p ${linkDirectory}
    execute cd ${linkDirectory}
    execute ln -sf ${pathToLink} ${relTagName}
    return
}
