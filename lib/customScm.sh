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
    cut -d/ -f 6 <<< ${url}
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

## @fn      actionCompare()
#  @brief   this command is called by jenkins custom scm plugin via a
#           polling trigger. It should decide, if a build is required
#           or not
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
# 
#           Idea: we get the information from the old build in the
#           BUILD_URL_LAST (old project name and old build
#           number). With this information we can look for the
#           revisions.txt file, which is located on the jenkins
#           master server in the build directory of the old build
#           ($JENKINS_HOME/jobs/<projekt>/builds/<number>). In the next
#           step, we have to create the same revisions.txt for the head
#           revisions of the used svn repos (we need the svn urls with
#           branches, ...) which are used in the trunk / branch. This
#           info is located in the locations/<branch>/Dependencies
#           files. So the steps got the the new revisions.txt are:
# 
#           * get the branch / trunk information (use the job name)
# 
#           * get the locations/<branch>/Dependencies file from svn
#           (svn cat <url>)
# 
#           * generate all urls from "build listdirs" (aka
#           grep -h '^'"dir " locations/*/Dependencies) and
#           locations/<branch>/Dependencies with revisions
# 
#           * if the new generated and the old, stored files are
#           different, trigger a new build, and store the new file
# 
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {

    if [[ -z "${REVISION_STATE_FILE}" ]] ; then
        info "no old revision state file found"
        exit 0
    fi

    # getting old revision file 
    oldRevisionsFile=$(createTempFile)

    local oldProjectName=$(getJobNameFromUrl     ${BUILD_URL_LAST})
    local oldBuildNumber=$(getBuildNumberFromUrl ${BUILD_URL_LAST})

    info "last project was ${oldProjectName} / ${oldBuildNumber}"
    oldRevisionsFileOnServer=${jenkinsMasterServerPath}/jobs/${oldProjectName}/builds/${oldBuildNumber}/revisions.txt
    if ! runOnMaster test -e ${oldRevisionsFileOnServer} ; then
        info "revisions file does not exist, trigger new build"
        exit 0
    fi

    execute rsync -ae ssh ${jenkinsMasterServerHostName}:${oldRevisionsFileOnServer} \
                          ${oldRevisionsFile}

    # generate the new revsions file
    newRevisionsFile=$(createTempFile)
    _createRevisionsTxtFile ${newRevisionsFile}

    # now we have both files, we can compare them
    if cmp --silent ${oldRevisionsFile} ${newRevisionsFile} ; then
        info "no changes in revision files, no build required"
        execute diff -rub ${oldRevisionsFile} ${newRevisionsFile}
        exit 1
    fi

    return
}


## @fn      _createRevisionsTxtFile( $fileName )
#  @brief   create the revisions.txt file 
#  @details see actionCompare for more details
#  @param   {fileName}    file name
#  @param   <none>
#  @return  <none>
_createRevisionsTxtFile() {

    local newRevisionsFile=$1
    dependenciesFile=$(createTempFile)
    
    locationName=$(getLocationName)
    mustHaveLocationName

    # get the locations/<branch>/Dependencies
    dependenciesFileUrl=${lfsSourceRepos}/os/trunk/bldtools/locations-${locationName}/Dependencies
    if ! svn ls ${dependenciesFileUrl} 2>/dev/null
    then
        error "svn is not responding or ${dependenciesFileUrl}does not exist"
        exit 1
    fi

    # can not use execute here, so we have to do the error handling by hande
    # do the magic for all dir
    ${LFS_CI_ROOT}/bin/getRevisionTxtFromDependencies -u ${dependenciesFileUrl} -f ${dependenciesFile} > ${newRevisionsFile} 
    if [[ $? != 0 ]] ; then
        error "reported an error..."
        exit 1
    fi

    return
}

## @fn      actionCheckout()
#  @brief   action which is called by custom scm jenkins plugin to create or update a workspace
#  @details 
#  @param   <none>
#  @return  <none>
actionCheckout() {
    # changelog handling
    # idea: the upstream project has the correct change log. We have to get it from them.
    # For this, we get the old revision state file and the revision state file.
    # This includes the upstream project name and the upstream build number.
    # So the job is easy: get the changelog of the upstream project builds between old and new
    #
    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"

    echo "get the old upstream project data..."
    { read oldUpstreamProjectName ; read oldUpstreamBuildNumber ;  } < "${OLD_REVISION_STATE_FILE}"
    echo "old upstream project data are: ${oldUpstreamProjectName} / ${oldUpstreamBuildNumber}"

    build=${UPSTREAM_BUILD}
    while [[ ${build} -gt ${oldUpstreamBuildNumber} ]] ; do
        buildDirectory=/var/fpwork/demx2fk3/lfs-jenkins/home/jobs/${UPSTREAM_PROJECT}/builds/${build}
        # we must only concatenate non-empty logs; empty logs with a
        # single "<log/>" entry will break the concatenation:
        ssh maxi.emea.nsn-net.net "grep -q logentry \"${buildDirectory}/changelog.xml\" && cat \"${buildDirectory}/changelog.xml\"" >> ${CHANGELOG}
        build=$(( build - 1 ))
    done

    # Remove inter-log cruft arising from the concatenation of individual
    # changelogs:
    sed -i 's:</log><?xml[^>]*><log>::g' "$CHANGELOG"

    # Fix empty changelogs:
    if [ ! -s "$CHANGELOG" ] ; then
        echo -n "<log/>" >"$CHANGELOG"
    fi


     exit 0
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details �full description�
#  @param   <none>
#  @return  <none>
actionCalculate() {

    debug "creating revision state file ${REVISION_STATE_FILE}"
    echo ${UPSTREAM_PROJECT}   >   "${REVISION_STATE_FILE}"
    echo ${UPSTREAM_BUILD}     >>  "${REVISION_STATE_FILE}"

    # generate the new revsions file
    newRevisionsFile=$(createTempFile)
    _createRevisionsTxtFile ${newRevisionsFile}

    execute rsync -ae ssh ${newRevisionsFile} \
                ${jenkinsMasterServerPath}/jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/revisions.txt

    return 
}

return
