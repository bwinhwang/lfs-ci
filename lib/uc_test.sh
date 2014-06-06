#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh

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

    if [[ ! ${upstreamProject} ]] ; then
        upstreamBuildNumber=lastSuccessfulBuild
        upstreamProject=$(sed "s/Test/Build/" <<< ${JOB_NAME})
    fi

    # find the related jobs of the build
    local upstreamsFile=$(createTempFile)
    runOnMaster ${LFS_CI_ROOT}/bin/getUpStreamProject \
                    -j ${upstreamProject}             \
                    -b ${upstreamBuildNumber}         \
                    -h ${serverPath}  > ${upstreamsFile}

    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1)
    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2)
    mustHaveValue ${packageJobName}
    mustHaveValue ${packageBuildNumber}
    mustHaveValue ${buildJobName}
    mustHaveValue ${buildBuildNumber}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}"
    return
}
