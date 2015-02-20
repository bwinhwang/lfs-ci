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
    if [[ "${upstreamProjectName}" != "${oldUpstreamProjectName}" ]] ; then
        info "upstream project name changed, trigger build"
        exit 0
    fi

    local changelog=$(createTempFile)
    _createChangelog ${oldUpstreamBuildNumber} ${upstreamBuildNumber} ${changelog}

    if egrep -q -e '%FIN %PR=[0-9]+ESPE[09-]+' ${changelog} ; then
        info "found in comments '%FIN %PR=<pronto>', trigger build"
        exit 0
    fi

    info "no pronto found between ${oldUpstreamProjectName}#${oldUpstreamBuildNumber} and ${upstreamProjectName}#${upstreamBuildNumber} => No build."
    exit 1
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
#  @brief   action ...
#  @details 
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

    return 0
}


_createChangelog() {
    local oldUpstreamBuildNumber=$1
    local upstreamBuildNumber=$2
    local changeLog=$3

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

_getUpstream() {

    requiredParameters JOB_NAME LFS_CI_ROOT

    upstreamProjectName=${UPSTREAM_PROJECT}
    upstreamBuildNumber=${UPSTREAM_BUILD}

    debug "build was triggered manually, get last promoted upstream"
    # workaround
    local backlogItemTwentyFiveMigration=$(getConfig backlogItemTwentyFiveMigration)

    if [[ ${backlogItemTwentyFiveMigration} ]] ; then
        upstreamProjectName=$(sed 's/\(.*\)_Prod_-_\(.*\)_-_Releasing_-_summary/\1_CI_-_\2_-_Wait_for_release/' <<< ${JOB_NAME} )
    else
        upstreamProjectName=$(sed 's/\(.*\)_Prod_-_\(.*\)_-_Releasing_-_summary/\1_CI_-_\2_-_Test/' <<< ${JOB_NAME} )
    fi

    copyFileFromBuildDirectoryToWorkspace "${upstreamProjectName}/promotions/Test_ok" "lastStableBuild" build.xml
    mustExistFile ${WORKSPACE}/build.xml

    local xml='hudson.plugins.promoted__builds.Promotion/actions/hudson.plugins.promoted__builds.PromotionTargetAction/number/node()' 
    upstreamBuildNumber=$(${LFS_CI_ROOT}/bin/xpath -q -e ${xml} ${WORKSPACE}/build.xml)

    execute rm -rf ${WORKSPACE}/build.xml
        
    return
}
