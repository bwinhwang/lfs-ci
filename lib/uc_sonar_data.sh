#!/bin/bash

# @file uc_sonar_data.sh
# @brief copy the data used by sonar to according dir in /userData

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh

## @fn      usecase_LFS_COPY_SONAR_UT_DATA()
#  @brief   copy the unittest data used for sonar to Jenkins userContent directory
#  @param   <none>
#  @return  <none>
usecase_LFS_COPY_SONAR_UT_DATA() {

    requiredParameters JOB_NAME

    local sonarDataPath=$(getConfig LFS_CI_unittest_coverage_data_path)

    local targetType=$(getSubTaskNameFromJobName)
    mustHaveValue ${targetType} "target type"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    local userContentPath=sonar/UT/${targetType}

    _copy_Sonar_Data_to_userContent ${workspace}/${sonarDataPath} sonar/UT/${targetType}
    
    return 0
}

## @fn      usecase_LFS_COPY_SONAR_SCT_DATA()
#  @brief   copy the system component test data used for sonar to Jenkins userContent directory
#  @param   <none>
#  @return  <none>
usecase_LFS_COPY_SONAR_SCT_DATA() {

    requiredParameters JOB_NAME

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    for targetType in FSMr3 FSMr4
    do

        local sonarDataPath=$(eval echo $(getConfig LFS_CI_unittest_coverage_data_path))
        local userContentPath=sonar/SCT/${targetType}

        _copy_Sonar_Data_to_userContent ${workspace}/${sonarDataPath} ${userContentPath}

    done
    return 0
}

## @fn      _copy_Sonar_Data_to_userContent()
#  @brief   copy the sonar data files coverage.xml.gz and testcases.merged.xml.gz 
#  @param   {sonarDataDir}   directory where the files to be copied will be found
#  @param   {userContentDir} directory (in Jenkins/userContent) where the files will be copied to
#  @return  <none>
_copy_Sonar_Data_to_userContent () {

    local sonarDataDir=$1
    local userContentDir=$2


    for dataFile in coverage.xml.gz testcases.merged.xml.gz 
    do
        if [[ -e ${sonarDataDir}/${dataFile} ]] ; then
            debug  now copying ${sonarDataDir}/${dataFile} to ${userContentDir} ...
            copyFileToUserContentDirectory ${sonarDataDir}/${dataFile} ${userContentDir}
        else
            info  ${sonarDataDir}/${dataFile} not found!
        fi
    done
    
    return 0
}

