#!/bin/bash

usecase_LFS_READY_FOR_RELEASE() {

    requiredParameters UPSTREAM_BUILD UPSTREAM_PROJECT

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"
    createArtifactArchive

    copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fingerprint.txt
    copyFileFromWorkspaceToBuildDirectory ${JOB_NAME}         ${BUILD_NUMBER}   fingerprint.txt

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${label}"
    
    return
}

