#!/bin/bash

[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      ci_job_test()
#  @brief   dispatcher for test jobs
#  @details prepare the build artifacts to have it in the correct way for the test framework
#  @param   <none>
#  @return  <none>
ci_job_test() {
    # get the package build job (upstream_project and upstream_build)
    # prepare the workspace directory for all test builds
    # copy the files to a workspace directory
    # jobs will be executed by jenkins job, so we can exit very early
    requiredParameters JOB_NAME BUILD_NUMBER WORKSPACE UPSTREAM_PROJECT UPSTREAM_BUILD

    local upstreamProject=${UPSTREAM_PROJECT}
    local upstreamBuildNumber=${UPSTREAM_BUILD}
    info "upstreamProject data: ${upstreamProject} / ${upstreamBuildNumber}"

    local requiredArtifacts=$(getConfig LFS_CI_UC_test_required_artifacts)
    copyArtifactsToWorkspace "${upstreamProject}" "${upstreamBuildNumber}" "${requiredArtifacts}"

    # structure of jobs
    # Test
    #  |--- FSM-r2 summary
    #  |     \---- Test-fsmr2_target1
    #  |--- FSM-r3 summary
    #  |     |---- Test-fsmr3_target1
    #  |     |---- Test-fsmr3_target2
    #  |     \---- Test-fsmr3_target3
    #  \--- FSM-r4 summary
    #        |---- Test-fsmr4_target1
    #        |---- Test-fsmr4_target2
    #        \---- Test-fsmr4_target3
    # if we are the Test job, we have to prepare the upstream data for the downstream jobs          
    if [[ ${JOB_NAME} =~ .*_-_Test$ ]] ; then

        debug "we are the summary test job"

        local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
        local workspace=${ciBuildShare}/build_${upstreamBuildNumber}
        mustExistSymlink ${workspace}

        local realDirectory=$(readlink ${workspace})
        local labelName=$(basename ${realDirectory})
        mustExistDirectory ${realDirectory}
        mustHaveValue "${labelName}" "label name from ${workspace}"

        info "using build ${labelName} in ${realDirectory}"

        info "creating upstream file in workspace"
        execute rm -rf ${WORKSPACE}/upstream
        echo "upstreamProject=${upstreamProject}"          > ${WORKSPACE}/upstream
        echo "upstreamBuildNumber=${upstreamBuildNumber}" >> ${WORKSPACE}/upstream
        rawDebug ${WORKSPACE}/upstream

        copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${WORKSPACE}/upstream

        execute rm -rf ${WORKSPACE}/properties
        echo "LABEL=${labelName}"                   > ${WORKSPACE}/properties
        echo "DELIVERY_DIRECTORY=${realDirectory}" >> ${WORKSPACE}/properties
        rawDebug ${WORKSPACE}/properties

        copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${WORKSPACE}/properties

    else

        debug "we are the slave test job"

        info "overwrite upstreamProject to ${upstreamProject} ${upstreamBuildNumber}"
        copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} upstream 
        mustExistFile ${WORKSPACE}/upstream
        rawDebug ${WORKSPACE}/upstream

        source ${WORKSPACE}/upstream

        info "overwrite upstreamProject to ${upstreamProject} ${upstreamBuildNumber}"
        copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} properties 
        mustExistFile ${WORKSPACE}/properties
        rawDebug ${WORKSPACE}/properties

        source ${WORKSPACE}/properties

        # for setBuildDescription
        local labelName=${LABEL}
    fi

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"
    return
}


ci_job_test_collect_metrics() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    local testJobData=$(getDownStreamProjectsData ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    info ${testJobData}

    local buildJobName=$(getBuildJobNameFromUpstreamProject)
    local buildBuildNumber=$(getBuildBuildNumberFromUpstreamProject)
    info "build job ${buildJobName} ${buildBuildNumber}"

    local downStreamData=$(getDownStreamProjectsData ${buildJobName} ${buildBuildNumber})
    info ${downStreamData}

    return
}
