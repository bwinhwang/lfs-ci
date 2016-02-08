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
    mustHaveValue "${sonarDataPath}" "sonar data path"

    local targetType=$(getSubTaskNameFromJobName)
    mustHaveValue "${targetType}" "target type"

    local subDir=UT
    local userContentPath=$(getConfig LFS_CI_usercontent_data_path -t targetType:${targetType} -t subDir:${subDir})
    mustHaveValue "${userContentPath}" "userContent path"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    _create_sonar_excludelist  ${workspace}/${sonarDataPath}/${targetType}_exclusions.txt
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

    local subDir=SCT

    for targetType in FSMr3 FSMr4
    do
        local sonarDataPath=$(getConfig LFS_CI_coverage_data_path -t targetType:${targetType})
        mustHaveValue "${sonarDataPath}" "sonar data path"
        local userContentPath=$(getConfig LFS_CI_usercontent_data_path -t targetType:${targetType} -t subDir:${subDir})
        mustHaveValue "${userContentPath}" "userContent path"

        _copy_Sonar_Data_to_userContent ${workspace}/${sonarDataPath} ${userContentPath}

    done
    return 0
}

## @fn      _copy_Sonar_Data_to_userContent()
#  @brief   copy the sonar data files coverage.xml.gz and testcases.merged.xml.gz 
#  @param   {sonarDataPath}   directory where the files to be copied will be found
#  @param   {userContentPath} directory (in Jenkins/userContent) where the files will be copied to
#  @return  <none>
_copy_Sonar_Data_to_userContent () {

    local sonarDataPath=$1
    local userContentPath=$2

    local branchName=$(getBranchName)

    for dataFile in $(getConfig LFS_CI_coverage_data_files)
    do
        if [[ -e ${sonarDataPath}/${dataFile} ]] ; then
            debug  now copying ${sonarDataPath}/${dataFile} to ${userContentPath} ...
            copyFileToUserContentDirectory ${sonarDataPath}/${dataFile} ${userContentPath}
        else
            local severity=info
            local isFatalDataFilesMissing=$(getConfig LFS_CI_is_fatal_data_files_missing)
            [[ -n "${isFatalDataFilesMissing}" ]] && severity=fatal
            ${severity}  ${sonarDataPath}/${dataFile} not found!
        fi
    done
    
    return 0
}


## @fn      _create_sonar_excludelist()
#  @brief   create the exclusion list for sonar based on libFSMDDAL and the sourcefiles found in the repository
#  @param   {resfile} full path where to store the exclusion list
#  @return  <none>
_create_sonar_excludelist() {
    info Now creating exclusion list for Sonar ...

    local resfile=$1
    mustExistDirectory $(dirname $resfile)
    
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    # get path where to search for sourcefiles
    local spath=$(getConfig LFS_CI_sonar_exclusions_src_path)
    mustHaveValue "${spath}" "sonar exclusions source path"
    local srcdir=${workspace}/${spath}
    debug srcdir=${srcdir}

    info searching C files in src
    debug ignoring  tools DSDT fpa_test

    # the dirs ignored here get a special treatment below
    local temp1=$(createTempFile)
    ( cd $(dirname "$srcdir") && find $(basename "$srcdir") -name '*.c' ) | egrep -v '/stubs/|/tools/|/DSDT/|/fpa_test/' | sort > $temp1


    local targetType=$(getSubTaskNameFromJobName)
    debug targetType=$targetType
    mustHaveValue "${targetType}" "target type"

    # get path where to search for libFSMDDAL.a
    local lpath=$(getConfig LFS_CI_sonar_exclusions_lib_path -t targetType:${targetType})
    mustHaveValue "${lpath}" "sonar exclusions library path"
    local libpath=${workspace}/${lpath}
    debug libpath=${libpath}

    local temp2=$(createTempFile)
    ar t ${libpath}  > $temp2

    sed -i -e 's/\.o/\.c/' $temp2

    # remove some files that should always be blacklisted
    sed -i -e '/_stubs.c/d' -e '/^_version.c/d' -e '/fpa_test.c/d' -e '/ddal_auth_set_user_password_pam_pass_non_interractive.c/d' $temp2

    grep -v -f $temp2 $temp1 | sort > ${resfile}

    # add additional directories that should be left out completely
    for dir in tools/** stubs/** lx2/DSDT/** **/*.h
    do
        echo "src/$dir" >> ${resfile}
    done

    sed -i -e '$!s/$/ ,\\/' -e 's/^/**\//' ${resfile}

    return 0
}

