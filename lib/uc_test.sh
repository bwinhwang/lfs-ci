#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

## @fn      ci_job_test()
#  @brief   dispatcher for test jobs
#  @details prepare the build artifacts to have it in the correct way for the test framework
#  @param   <none>
#  @return  <none>
ci_job_test() {

    info "do nothing...."

    # TODO: demx2fk3 2014-04-16 add content here

    # get the package build job (upstream_project and upstream_build)
    # prepare the workspace directory for all test builds
    # copy the files to a workspace directory
    # jobs will be executed by jenkins job, so we can exit very early
    requiredParameters JOB_NAME 

    local serverPath=$(getConfig jenkinsMasterServerPath)
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local upstreamProject=${UPSTREAM_PROJECT}
    local upstreamBuildNumber=${UPSTREAM_BUILD}

    upstreamBuildNumber=lastSuccessfulBuild
    upstreamProject=$(sed "s/Test/Build/" <<< ${UPSTREAM_PROJECT})

    info "upstream is ${upstreamProject} / ${upstreamBuildNumber}"

    copyArtifactsToWorkspace "${upstreamProject}" "${upstreamBuildNumber}"

    mustHaveNextCiLabelName
    local labelName=$(getNextCiLabelName)        
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"
    return
}
