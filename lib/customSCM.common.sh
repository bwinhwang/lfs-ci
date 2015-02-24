#!/bin/bash

## @fn      dumpCustomScmEnvironmentVariables()
#  @brief   dump / show all environment variables which are related to Custom SCM Jenkins Plugin
#  @param   <none>
#  @return  <none>
dumpCustomScmEnvironmentVariables() {
    for var in BUILD_DIR               \
               BUILD_NUMBER            \
               BUILD_URL               \
               BUILD_URL_LAST          \
               BUILD_URL_LAST_STABLE   \
               BUILD_URL_LAST_SUCCESS  \
               CHANGELOG               \
               JENKINS_HOME            \
               JENKINS_URL             \
               JOB_DIR                 \
               JOB_NAME                \
               OLD_REVISION_STATE_FILE \
               REVISION_STATE_FILE     \
               UPSTREAM_BUILD          \
               UPSTREAM_JOB_URLS       \
               UPSTREAM_PROJECT        \
               WORKSPACE 
    do
        trace "$(printf "%25s %-30s\n" "${var}" "${!var}")"
    done

    return
}

## @fn      createPropertiesFileForBuild()
#  @brief   create a properties file, which are used by the build script.
#  @details format is bash. so you can source the file
#  @param   <none>
#  @return  <none>
createPropertiesFileForBuild() {
    execute rm -rf ${WORKSPACE}/.properties
    echo UPSTREAM_BUILD=${UPSTREAM_BUILD}     >  ${WORKSPACE}/.properties
    echo UPSTREAM_PROJECT=${UPSTREAM_PROJECT} >> ${WORKSPACE}/.properties
    return
}

## @fn      getBuildNumberFromUrl()
#  @brief   get the build number out of a jenkins url
#  @details the format is
#           http://maxi.emea.nsn-net.net:1280/job/custom_SCM_test_-_down/634/
#  @param   {url}    a jenkins url
#  @return  build number
getBuildNumberFromUrl() {
    local url=$1
    cut -d/ -f 6 <<< "${url}"
    return
}

## @fn      getJobNameFromUrl()
#  @brief   get the job name out of a jenkins url
#  @details the format is
#           http://maxi.emea.nsn-net.net:1280/job/custom_SCM_test_-_down/634/
#  @param   {url}    a jenkins url
#  @return  build number
getJobNameFromUrl() {
    local url=$1
    cut -d/ -f 5 <<< ${url}
    return
}

## @fn      getUpstreamProjectName()
#  @brief   get the upstream project name of the (optional) jobName / current job
#  @details this function is required, if the job was triggered by hand. we have to found out
#           what is the upstream job name to get everything working - like getting change notes
#           and artifacts from the upstream job
#  @param   {jobName}    name of the job (optional, default ${JOB_NAME})
#  @return  name of the upstream job
getUpstreamProjectName() {
    local jobName=$1

    if [[ -z ${jobName} ]] ; then
        requiredParameters JOB_NAME
        jobName=${JOB_NAME}
    fi
    local branchName=$(getBranchName)

    case ${jobName} in
        LFS_CI_-_trunk_-_Test)   echo LFS_CI_-_trunk_-_Package_-_package   ;;
        LFS_Post_-_trunk)        echo LFS_Prod_-_trunk_-_Releasing_-_summary ;;
        LFS_Post_-_*)            echo LFS_Prod_-_${branchName}_-_Releasing_-_summary ;;
        LFS_CI_-_*_-_Test)       echo LFS_CI_-_${branchName}_-_Package_-_package   ;;
        UBOOT_CI_-_*_-_Test)     echo UBOOT_CI_-_${branchName}_-_Package_-_package ;;
        *) fatal "no rule to get the upstream job for ${jobName}"              ;;
    esac

    return        
}
