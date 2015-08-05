#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

## @fn      ADMIN_ENABLE_JENKINS_JOB()
#  @brief   usecase Admin - enable a jenkins job
#  @param   <none>
#  @return  <none>
usecase_ADMIN_ENABLE_JENKINS_JOB() {

    requiredParameters JENKINS_JOB_NAME

    enableJobb ${JENKINS_JOB_NAME}
    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${JENKINS_JOB_NAME}"

    return
}

