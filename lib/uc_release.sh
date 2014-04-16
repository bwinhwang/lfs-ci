#!/bin/bash

ci_job_release() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    # setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "trunk-${BUILD_NUMBER}"

    # TODO: demx2fk3 2014-04-16 we need the svn revision "somehow"

    ${LFS_CI_ROOT}/bin/getUpStreamProject -j ${UPSTREAM_PROJECT} -b ${UPSTREAM_BUILD} -h ${jenkinsMasterServerPath}

    error "not implemented"

    return
}

