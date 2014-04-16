#!/bin/bash

ci_job_release() {

    requiredParameters JOB_NAME BUILD_NUMBER

    # setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "trunk-${BUILD_NUMBER}"

    # TODO: demx2fk3 2014-04-16 we need the svn revision "somehow"

    ${LFS_CI_ROOT}/bin/getUpStreamProject -j ${JOB_NAME} -b ${BUILD_NUMBER} -h ${jenkinsMasterServerPath}

    error "not implemented"

    return
}

