#!/bin/bash

ci_job_release() {

    requiredParameters JOB_NAME BUILD_NUMBER

    # setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "trunk-${BUILD_NUMBER}"

    ${LFS_CI_ROOT}/bin/getUpStreamProject -j ${JOB_NAME} -b ${BUILD_NUMBER} -h ${jenkinsMasterServerPath}

    error "not implemented"

    return
}

