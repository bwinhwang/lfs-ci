#!/bin/bash
## @fn      actionCompare()
#  @brief   this command is called by jenkins custom scm plugin via a
#           polling trigger. It should decide, if a build is required
#           or not
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
# 
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {

    if [[ -z "${REVISION_STATE_FILE}" ]] ; then
        info "no old revision state file found"
        exit 0
    fi

    # set variables upstreamProjectName and upstreamBuildNumber
    _getUpstream

    # read the revision state file
    # format:
    # projectName
    # buildNumber
    { read oldUpstreamProjectName ; 
      read oldUpstreamBuildNumber ; } < "${REVISION_STATE_FILE}"

    trace "old upstream project was ${oldUpstreamProjectName} / ${oldUpstreamBuildNumber}"
    trace "new upstream project was ${upstreamProjectName} / ${upstreamBuildNumber}"

    # comparing to new state
#    if [[ "${upstreamProjectName}" != "${oldUpstreamProjectName}" ]] ; then
#        info "upstream project name changed, trigger build"
#        exit 0
#    fi


    local changelog=$(createTempFile)
    _createChangelog ${oldUpstreamBuildNumber} ${upstreamBuildNumber} ${changelog}
    _checkReleaseForPronto          ${changelog}
    _checkReleaseForRelevantChanges ${changelog}
    _checkReleaseForEmptyChangelog  ${changelog}

    if [[ "${upstreamBuildNumber}" != "${oldUpstreamBuildNumber}" ]] ; then
        info "upstream build number has changed, trigger build"
        exit 0
    fi

    info "no relevant changes found between ${oldUpstreamProjectName}#${oldUpstreamBuildNumber} and ${upstreamProjectName}#${upstreamBuildNumber} => No build/release."
    exit 1
}

## @fn      _checkReleaseForPronto()
#  @brief   check the changelog for a change, which contains a pronto id
#  @param   {changelog}    name of the changelog
#  @return  <none>
#  @return  1 if there is no pronto id in the changelog, 0 otherwise
_checkReleaseForPronto() {
    local changelog=$1

    local canCheckForPronto=$(getConfig CUSTOM_SCM_release_check_for_pronto)
    if [[ ! ${canCheckForPronto} ]] ; then
        warning "check for pronto in release is disabled"
        return 1
    fi
    if egrep -q -e '%FIN %PR=PR[0-9]+' ${changelog} ; then
        info "found in comments '%FIN %PR=<pronto>', trigger build"
        exit 0
    fi

    return 1
}

## @fn      _checkReleaseForEmptyChangelog()
#  @brief   check the changelog for a empty changelog
#  @param   {changelog}    name of the changelog
#  @return  1 if the changelog is not empty, 0 otherwise
_checkReleaseForEmptyChangelog() {
    local changelog=$1

    local canCheckForEmptyChangelog=$(getConfig CUSTOM_SCM_release_check_for_empty_changelog)
    if [[ ! ${canCheckForEmptyChangelog} ]] ; then
        warning "check for empty changelog in release is disabled"
        return 1
    fi
    if ! grep -q -e 'logentry' ${changelog} ; then
        info "changelog is empty"
        exit 1
    fi

    return 0
}

## @fn      _checkReleaseForRelevantChanges()
#  @brief   check the changelog for relevant changes.
#  @details there is a filter file in etc/customSCM.release.filter.*.txt, which defines a list
#           of components, which are not relevant for release. So you can list src-test or src-unittests
#           in the filter file. If there are only changes in src-test in the changelog, the
#           release candidate will be not released.
#  @param   {changelog}    name of the changelog
#  @return  1 if there are norelevant changes, 0 otherwise
_checkReleaseForRelevantChanges() {
    local changelog=${1}

    local canCheckForRelevantChanges=$(getConfig CUSTOM_SCM_release_check_for_relevant_changes)
    if [[ ! ${canCheckForRelevantChanges} ]] ; then
        warning "check for empty changelog in release is disabled"
        return 1
    fi

    local file=$(createTempFile)
    local filterFile=$(getConfig CUSTOM_SCM_release_check_for_relevant_change_filter_file)

    if [[ ! -f ${filterFile} ]] ; then
        info "no filter file for relevant changes found => no check"
        return 1
    fi

    execute -l ${file} ${LFS_CI_ROOT}/bin/xpath -q -e '/log/logentry/paths/path/node()' ${changelog}
    local countAllChanges=$(wc -l ${file} | cut -d" " -f 1)
    local countRelevantChanges=$(grep -v -f ${filterFile} ${file} | wc -l)

    if [[ ${countRelevantChanges} == ${countAllChanges} ]] ; then
       info "all changes are relevent for release"
       exit 0
    fi

    return 1
}

## @fn      actionCheckout()
#  @brief   action which is called by custom scm jenkins plugin to create or update a workspace and create the changelog
#  @details the create workspace task is empty here. We just calculate the changelog
#  @param   <none>
#  @return  <none>
actionCheckout() {
    # changelog handling
    # idea: the upstream project has the correct change log. We have to get it from them.
    # For this, we get the old revision state file and the revision state file.
    # This includes the upstream project name and the upstream build number.
    # So the job is easy: get the changelog of the upstream project builds between old and new

    if [[ -e ${OLD_REVISION_STATE_FILE} ]] ; then
        debug "get the old upstream project data... from ${OLD_REVISION_STATE_FILE}"
        { read oldUpstreamProjectName ; 
          read oldUpstreamBuildNumber ;  } < "${OLD_REVISION_STATE_FILE}"
        debug "old upstream project data are: ${oldUpstreamProjectName} / ${oldUpstreamBuildNumber}"
    else
        debug "old revision state file does not exist."
        oldUpstreamBuildNumber=1
    fi

    # set variables upstreamProjectName and upstreamBuildNumber
    _getUpstream

    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"
    _createChangelog ${oldUpstreamBuildNumber} ${upstreamBuildNumber} ${CHANGELOG}

    # Fix empty changelogs:
    if [ ! -s "$CHANGELOG" ] ; then
        echo -n "<log/>" >"$CHANGELOG"
    fi

    return
}

## @fn      actionCalculate()
#  @brief   calculate action of custom SCM
#  @param   <none>
#  @return  <none>
actionCalculate() {

    # set variables upstreamProjectName and upstreamBuildNumber
    _getUpstream

    debug "creating revision state file ${REVISION_STATE_FILE}"
    echo ${upstreamProjectName} >  "${REVISION_STATE_FILE}"
    echo ${upstreamBuildNumber} >> "${REVISION_STATE_FILE}"

    # upstream handling if missing
    debug "storing upstream info in .properties"
    echo TESTED_BUILD_JOBNAME=${upstreamProjectName} >  ${WORKSPACE}/.properties
    echo TESTED_BUILD_NUMBER=${upstreamBuildNumber}  >> ${WORKSPACE}/.properties
    echo UPSTREAM_PROJECT=${upstreamProjectName}     >> ${WORKSPACE}/.properties
    echo UPSTREAM_BUILD=${upstreamBuildNumber}       >> ${WORKSPACE}/.properties

    return 0
}


## @fn      _createChangelog()
#  @brief   create the changelog
#  @param   {oldUpstreamBuildNumber}    old upstream build number
#  @param   {upstreamBuildNumber}       upstream build number
#  @param   {changeLog}                 name of the changelog
#  @return  <none>
_createChangelog() {
    local oldUpstreamBuildNumber=$1
    local upstreamBuildNumber=$2
    local changeLog=$3

    # TODO: demx2fk3 2015-03-09 FIXME SSH_LOAD replace this with other server
    local server=$(getConfig jenkinsMasterServerHostName)

    local build=${upstreamBuildNumber}
    while [[ ${build} -gt ${oldUpstreamBuildNumber} ]] ; do
        local buildDirectory=$(getBuildDirectoryOnMaster ${upstreamProjectName} ${build})
        # we must only concatenate non-empty logs; empty logs with a
        # single "<log/>" entry will break the concatenation:
        debug "checking ${upstreamProjectName} / ${build} "

        # TODO: demx2fk3 2014-04-07 use configuration for this
        local tmpChangeLogFile=$(createTempFile)
        debug "changelog ${buildDirectory}/changelog.xml"
        ssh ${server} "test -f ${buildDirectory}/changelog.xml && grep -q logentry ${buildDirectory}/changelog.xml && cat ${buildDirectory}/changelog.xml" > ${tmpChangeLogFile}
        if [[ ! -s ${changeLog} ]] ; then
            debug "copy ${tmpChangeLogFile} to ${changeLog}"
            execute cp -f ${tmpChangeLogFile} ${changeLog}
        else
            debug "using xsltproc to create new ${changeLog}"
            local newTmpChangeLogFile=$(createTempFile)
            execute xsltproc                                          \
                        --stringparam file ${tmpChangeLogFile}        \
                        --output ${changeLog}                         \
                        ${LFS_CI_ROOT}/lib/contrib/joinChangelog.xslt \
                        ${changeLog}  
        fi

        build=$(( build - 1 ))
    done

    rawDebug ${CHANGELOG}

    return
}

## @fn      _getUpstream()
#  @brief   get the name of the upstream job 
#  @param   <none>
#  @return  <none>
_getUpstream() {

    requiredParameters JOB_NAME LFS_CI_ROOT

    upstreamProjectName=${UPSTREAM_PROJECT}
    upstreamBuildNumber=${UPSTREAM_BUILD}

    debug "build was triggered manually, get last promoted upstream"
    upstreamProjectName=$(sed 's/\(.*\)_Prod_-_\(.*\)_-_Releasing_-_summary/\1_CI_-_\2_-_Wait_for_release/' <<< ${JOB_NAME} )

    copyFileFromBuildDirectoryToWorkspace "${upstreamProjectName}/promotions/Test_ok" "lastStableBuild" build.xml
    mustExistFile ${WORKSPACE}/build.xml

    local xml='hudson.plugins.promoted__builds.Promotion/actions/hudson.plugins.promoted__builds.PromotionTargetAction/number/node()' 
    upstreamBuildNumber=$(${LFS_CI_ROOT}/bin/xpath -q -e ${xml} ${WORKSPACE}/build.xml)

    execute rm -rf ${WORKSPACE}/build.xml
        
    return
}
