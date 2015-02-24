#!/bin/bash
## @file  uc_test
#  @brief the test usecase

[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_database}  ]] && source ${LFS_CI_ROOT}/lib/database.sh

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

    local buildJobName=$(getBuildJobNameFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    local buildBuildNumber=$(getBuildBuildNumberFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})

    local requiredArtifacts=$(getConfig LFS_CI_UC_test_required_artifacts)
    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "${requiredArtifacts}"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

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

        local labelName=""
        if [[ -e ${workspace}/bld/bld-fsmci-summary/label ]] ; then
            mustHaveNextCiLabelName
            labelName=$(getNextCiLabelName)
        else
            # TODO: demx2fk3 2015-02-24 should / can be removed
            local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
            local workspace=${ciBuildShare}/build_${upstreamBuildNumber}
            mustExistSymlink ${workspace}

            local realDirectory=$(readlink ${workspace})
            labelName=$(basename ${realDirectory})
        fi

        mustHaveValue "${labelName}" "label name"

        local deliveryDirectory=$(getConfig LFS_CI_UC_package_copy_to_share_name)/\
                                $(getConfig LFS_CI_UC_package_copy_to_share_path_name)/\
                                ${labelName}

        mustExistDirectory ${deliveryDirectory}

        info "using build ${labelName} in ${deliveryDirectory}"

        info "creating upstream file in workspace"

        echo "upstreamProject=${upstreamProject}"          > ${workspace}/upstream
        echo "upstreamBuildNumber=${upstreamBuildNumber}" >> ${workspace}/upstream
        rawDebug ${workspace}/upstream

        copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${workspace}/upstream


        echo "LABEL=${labelName}"                       > ${workspace}/properties
        echo "DELIVERY_DIRECTORY=${deliveryDirectory}" >> ${workspace}/properties
        rawDebug ${workspace}/properties

        copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${workspace}/properties

    else

        debug "we are the slave test job"

        info "overwrite upstreamProject to ${upstreamProject} ${upstreamBuildNumber}"
        copyFileFromBuildDirectoryToWorkspace ${upstreamProject} ${upstreamBuildNumber} upstream 
        mustExistFile ${WORKSPACE}/upstream
        rawDebug ${WORKSPACE}/upstream

        source ${WORKSPACE}/upstream

        info "overwrite upstreamProject to ${upstreamProject} ${upstreamBuildNumber}"
        copyFileFromBuildDirectoryToWorkspace ${upstreamProject} ${upstreamBuildNumber} properties 
        mustExistFile ${WORKSPACE}/properties
        rawDebug ${WORKSPACE}/properties

        source ${WORKSPACE}/properties

        # for setBuildDescription
        local labelName=${LABEL}
    fi

    info "copy dummy test junit xml file into workspace"
    execute cp ${LFS_CI_ROOT}/etc/junit_dummytest.xml ${WORKSPACE}

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"

    createArtifactArchive

    return
}


