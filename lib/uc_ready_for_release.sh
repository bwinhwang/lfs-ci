#!/bin/bash

usecase_LFS_READY_FOR_RELEASE() {

    requiredParameters UPSTREAM_BUILD UPSTREAM_PROJECT

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"
    createArtifactArchive

    copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fingerprint.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME}         ${BUILD_NUMBER}   fingerprint.txt

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    createReleaseLinkOnCiLfsShare ${labelName}

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${label}"
    
    return
}

createReleaseLinkOnCiLfsShare() {
    local labelName=$1
    local linkDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_link_location)
    local pathToLink=../../$(getConfig LFS_CI_UC_package_copy_to_share_path_name)/${labelName}
    local relTagName=${labelName//PS_LFS_OS_/PS_LFS_REL_}
    info "creating link in CI_LFS RCversion ${relTagName}"
    execute mkdir -p ${linkDirectory}
    execute cd ${linkDirectory}
    execute ln -sf ${pathToLink} ${relTagName}
    return
}
