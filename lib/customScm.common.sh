#!/bin/bash

## @fn      dumpCustomScmEnvironmentVariables(  )
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
        debug "$(printf "%30s %-30s\n" "${var}" "${!var}")"
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

## @fn      getBuildNumberFromUrl( $url  )
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

## @fn      getJobNameFromUrl( $url  )
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
