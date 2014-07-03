#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

## @fn      ci_job_test()
#  @brief   dispatcher for test jobs
#  @details prepare the build artifacts to have it in the correct way for the test framework
#  @param   <none>
#  @return  <none>
ci_job_test() {

    # TODO: demx2fk3 2014-04-16 add content here

    # get the package build job (upstream_project and upstream_build)
    # prepare the workspace directory for all test builds
    # copy the files to a workspace directory
    # jobs will be executed by jenkins job, so we can exit very early
    requiredParameters JOB_NAME 

    local serverPath=$(getConfig jenkinsMasterServerPath)
    local workspace=$(getWorkspaceName)
    local ciBuildShare=$(getConfig lfsCiBuildsShare)
    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"

    local location=$(getBranchName)
    mustHaveBranchName

    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local upstreamProject=$(sed "s/Test.*/Package_-_package/" <<< ${JOB_NAME})
    local upstreamBuildNumber=$(readlink ${serverPath}/jobs/${upstreamProject}/builds/lastSuccessfulBuild)
    info ${serverPath}/jobs/${upstreamProject}/builds/lastSuccessfulBuild
    info "upstreamProject ${upstreamProject} ${upstreamBuildNumber}"

    # copyArtifactsToWorkspace "${upstreamProject}" "${upstreamBuildNumber}" "${requiredArtifacts}"
    local workspace=${ciBuildShare}/${productName}/${location}/build_${upstreamBuildNumber}

    echo "FUPPER_IMAGE=${workspace}/os/platforms/fsm3_octeon2/factory/fsm3_octeon2-fupper_images.sh" > ${WORKSPACE}/properties
    echo "FMON_TGZ=${workspace}/os/platforms/fsm3_octeon2/apps/fmon.tgz" >> ${WORKSPACE}/properties

    # mustHaveNextCiLabelName
    # local labelName=$(getNextCiLabelName)        
    # setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"
    return
}
