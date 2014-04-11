#!/bin/bash

ci_job_release() {

    requiredParameters JOB_NAME BUILD_NUMBER

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "trunk-${BUILD_NUMBER}"

    return
}

