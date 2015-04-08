#!/bin/bash

## @file  uc_smoketest_postaction.sh"
#  @brief post action of a smoke tests
#  @details if the smoke tests are failing, the smoke tests will be disabled 
#           and the admins / production team will be informed.
#           No further tests are triggered.

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

usecase_LFS_SMOKE_TEST_POST_ACTION() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD

    warning "the smoke test failed on a or several targets."
    warning "the result of this action is: disable the smoke test and prevent further actions."

    info "disabling jenkins job ${UPSTREAM_PROJECT}"
    disableJob ${UPSTREAM_PROJECT}

    setBuildDescription "${UPSTREAM_PROJECT} / ${UPSTREAM_BUILD}"
    setBuildResultUnstable

    return
}

