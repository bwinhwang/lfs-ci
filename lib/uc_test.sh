#!/bin/bash

[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

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
    requiredParameters JOB_NAME BUILD_NUMBER WORKSPACE

    local serverPath=$(getConfig jenkinsMasterServerPath)
    local productName=$(getProductNameFromJobName)
    mustHaveValue "${productName}" "product name"

    local location=$(getBranchName)
    mustHaveBranchName

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    # local upstreamProject=${UPSTREAM_PROJECT}
    # local upstreamBuildNumber=${UPSTREAM_BUILD}
    # info "upstreamProject ${upstreamProject} ${upstreamBuildNumber}"

    # TODO fixme
    local upstreamProject=$(sed "s/Test.*/Package_-_package/" <<< ${JOB_NAME})
    local upstreamBuildNumber=$(readlink ${serverPath}/jobs/${upstreamProject}/builds/lastSuccessfulBuild)
    info "upstreamProject ${upstreamProject} ${upstreamBuildNumber}"

    local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
    local workspace=${ciBuildShare}/build_${upstreamBuildNumber}
    mustExistSymlink ${workspace}

    local realDirectory=$(readlink ${workspace})
    local labelName=$(basename ${realDirectory})
    mustExistDirectory ${realDirectory}
    mustHaveValue "${labelName}" "label name from ${workspace}"

    execute rm -rf ${WORKSPACE}/properties
    echo "LABEL=${labelName}"                  >> ${WORKSPACE}/properties
    echo "DELIVERY_DIRECTORY=${realDirectory}" >> ${WORKSPACE}/properties
    rawDebug ${WORKSPACE}/properties

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"
    return
}

ci_job_test_summary() {
    requiredParameters WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
    local workspace=${ciBuildShare}/build_${UPSTREAM_BUILD}
    mustExistSymlink ${workspace}

    local realDirectory=$(readlink ${workspace})
    local labelName=$(basename ${realDirectory})

    echo "upstreamProject=${UPSTREAM_PROJECT}"   > ${WORKSPACE}/upstream
    echo "upstreamBuildNumber=${UPSTREAM_BUILD}" > ${WORKSPACE}/upstream

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"

    return
}
