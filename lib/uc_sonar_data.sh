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

    local sonarDataPath=$(getConfig LFS_CI_coverage_data_path)

    local targetType=$(getSubTaskNameFromJobName)
    mustHaveValue ${targetType} "target type"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    local userContentPath=sonar/UT/${targetType}

    _copy_Sonar_Data_to_userContent ${workspace}/${sonarDataPath} ${userContentPath}
    
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
        #TODO: the following eval construct shouldn't be necessary, but it doesnt work in Jenkins otherwise
        # further investigation needed
        local sonarDataPath==$(getConfig LFS_CI_coverage_data_path -t targetType:${targetType})
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

    local branchName = $(getBranchName)

    for dataFile in $(getConfig LFS_CI_coverage_data_files -t branchName:${branchName})
    do
        if [[ -e ${sonarDataDir}/${dataFile} ]] ; then
            debug  now copying ${sonarDataDir}/${dataFile} to ${userContentDir} ...
            copyFileToUserContentDirectory ${sonarDataDir}/${dataFile} ${userContentDir}
        else
            local severity=info
            local isFatalDataFilesMissing=$(getConfig LFS_CI_is_fatal_data_files_missing)
            [[ -n "${isFatalDataFilesMissing}" ]] && severity=fatal
            ${severity}  ${sonarDataDir}/${dataFile} not found!
        fi
    done
    
    return 0
}

