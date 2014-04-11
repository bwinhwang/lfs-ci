#!/bin/bash

ci_job_release() {
    echo ok

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "trunk-${BUILD_NUMBER}"

    return
}

