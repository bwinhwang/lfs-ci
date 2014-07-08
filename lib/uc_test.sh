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

    local upstreamProject=$(sed "s/Test.*/Package_-_package/" <<< ${JOB_NAME})
    local upstreamBuildNumber=$(readlink ${serverPath}/jobs/${upstreamProject}/builds/lastSuccessfulBuild)
    info "upstreamProject ${upstreamProject} ${upstreamBuildNumber}"
    local buildDirectory=$(getBuildDirectoryOnMaster "${upstreamProject}" lastSuccessfulBuild)
    mustExistDirectory ${buildDirectory}

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

    # echo "FUPPER_IMAGE=${workspace}/os/platforms/fsm3_octeon2/factory/fsm3_octeon2-fupper_images.sh" > ${WORKSPACE}/properties
    # echo "FMON_TGZ=${workspace}/os/platforms/fsm3_octeon2/apps/fmon.tgz" >> ${WORKSPACE}/properties
    # echo "EXECUTE_MANUAL=true" >> ${WORKSPACE}/properties
    # echo "LABEL=<a href=https://lfs-ci.emea.nsn-net.net/job/${JOB_NAME}/${BUILD_NUMBER}/>triggered by ${JOB_NAME}/${BUILD_NUMBER}</a>" >> ${WORKSPACE}/properties

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${label}"
    return
}
