#!/bin/bash

# @file uc_sonar_data.sh
# @brief copy the data used by sonar to according dir in /userData

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      usecase_LFS_COPY_SONAR_DATA()
#  @brief   copy the files used for sonar to userContent directory
#  @param   <none>
#  @return  <none>
usecase_LFS_COPY_SONAR_DATA() {

    requiredParameters JOB_NAME

    local sonarDataPath=$(getConfig LFS_CI_unittest_coverage_data_path)

    local targetType=$(getSubTaskNameFromJobName)
    mustHaveValue ${targetType} "target type"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    
    copyFileToUserContentDirectory ${workspace}/${sonarDataPath}/coverage.xml.gz sonar/${targetType}
    copyFileToUserContentDirectory ${workspace}/${sonarDataPath}/testcases.merged.xml.gz sonar/${targetType}

    return
}
