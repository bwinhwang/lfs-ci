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
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local upstreamProject=${UPSTREAM_PROJECT}
    local upstreamBuildNumber=${UPSTREAM_BUILD}
    local requiredArtifacts=$(getConfig LFS_CI_UC_test_required_artifacts)
    local upstreamsFile=$(createTempFile)

    runOnMaster ${LFS_CI_ROOT}/bin/getUpStreamProject \
                    -j ${upstreamProject}        \
                    -b ${upstreamBuildNumber}         \
                    -h ${serverPath} > ${upstreamsFile}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    if ! grep -q Package ${upstreamsFile} ; then
        error "cannot find upstream Package job"
        exit 1
    fi
    if ! grep -q Build   ${upstreamsFile} ; then
        error "cannot find upstream Build build"
        exit 1
    fi

    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1)
    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2)
    mustHaveValue ${packageJobName}
    mustHaveValue ${packageBuildNumber}
    mustHaveValue ${buildJobName}
    mustHaveValue ${buildBuildNumber}
    info "upstream is ${upstreamProject} / ${upstreamBuildNumber}"
    info "build    is ${buildJobName} / ${buildBuildNumber}"
    info "package  is ${packageJobName} / ${packageBuildNumber}"

    # copyArtifactsToWorkspace "${upstreamProject}" "${upstreamBuildNumber}" "${requiredArtifacts}"
    local workspace=${ciBuildShare}/${productName}/${location}/build_${packageBuildNumber}

    echo "FUPPER_IMAGE=${workspace}/os/platforms/fsm3_octeon2/factory/fsm3_octeon2-fupper_images.sh" > ${WORKSPACE}/properties
    echo "FMON_TGZ=${workspace}/os/platforms/fsm3_octeon2/apps/fmon.tgz" >> ${WORKSPACE}/properties

    mustHaveNextCiLabelName
    local labelName=$(getNextCiLabelName)        
    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"
    return
}
