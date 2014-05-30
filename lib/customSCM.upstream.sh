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

    local upstreamProjectName=${UPSTREAM_PROJECT}
    local upstreamBuildNumber=${UPSTREAM_BUILD}

    # read the revision state file
    # format:
    # projectName
    # buildNumber
    { read oldUpstreamProjectName ; 
      read oldUpstreamBuildNumber ; } < "${REVISION_STATE_FILE}"

    trace "old upstream project was ${oldProjectName} / ${oldBuildNumber}"

    # comparing to new state
    if [[ "${upstreamProjectName}" != "${oldUpstreamProjectName}" ]] ; then
        info "upstream project name changed, trigger build"
        exit 0
    fi

    if [[ "${upstreamBuildNumber}" != "${oldUpstreamBuildNumber}" ]] ; then
        info "upstream build number has changed, trigger build"
        exit 0
    fi

    info "upstream build ${upstreamProjectName}#${upstreamBuildNumber} was already tested"
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
    #
    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"

    local server=$(getConfig jenkinsMasterServerHostName)

    debug "get the old upstream project data..."
    { read oldUpstreamProjectName ; 
      read oldUpstreamBuildNumber ;  } < "${OLD_REVISION_STATE_FILE}"
    debug "old upstream project data are: ${oldUpstreamProjectName} / ${oldUpstreamBuildNumber}"

    build=${UPSTREAM_BUILD}
    while [[ ${build} -gt ${oldUpstreamBuildNumber} ]] ; do
        # TODO: demx2fk3 2014-04-07 use configuration for this
        buildDirectory=/var/fpwork/demx2fk3/lfs-jenkins/home/jobs/${UPSTREAM_PROJECT}/builds/${build}
        # we must only concatenate non-empty logs; empty logs with a
        # single "<log/>" entry will break the concatenation:
        debug "checking ${UPSTREAM_PROJECT} / ${build}"

        # TODO: demx2fk3 2014-04-07 use configuration for this
        local tmpChangeLogFile=$(createTempFile)
        ssh ${server} "test -f ${buildDirectory}/changelog.xml && grep -q logentry ${buildDirectory}/changelog.xml && cat ${buildDirectory}/changelog.xml" > ${tmpChangeLogFile}
        if [[ ! -s ${CHANGELOG} ]] ; then
            debug "copy ${tmpChangeLogFile} to ${CHANGELOG}"
            execute cp -f ${tmpChangeLogFile} ${CHANGELOG}
        else
            debug "using xsltproc to create new ${CHANGELOG}"
            local newTmpChangeLogFile=$(createTempFile)
            execute xsltproc                                          \
                        --stringparam file ${tmpChangeLogFile}        \
                        --output ${CHANGELOG}                         \
                        ${LFS_CI_ROOT}/lib/contrib/joinChangelog.xslt \
                        ${CHANGELOG}  
        fi

        build=$(( build - 1 ))
    done

    # Fix empty changelogs:
    if [ ! -s "$CHANGELOG" ] ; then
        echo -n "<log/>" >"$CHANGELOG"
    fi

    # copy revisions.txt from upstream
    if runOnMaster test -f ${buildDirectory}/revisionstate.xml ; then
        execute rsync -a ${server}:${buildDirectory}/revisionstate.xml ${WORKSPACE}/revisions.txt
    else
        touch ${WORKSPACE}/revisions.txt
    fi

    return
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details «full description»
#  @param   <none>
#  @return  <none>
actionCalculate() {

    debug "creating revision state file ${REVISION_STATE_FILE}"
    echo ${UPSTREAM_PROJECT}   >   "${REVISION_STATE_FILE}"
    echo ${UPSTREAM_BUILD}     >>  "${REVISION_STATE_FILE}"

    # upstream handling if missing
    echo UPSTREAM_PROJECT=${UPSTREAM_PROJECT}   > ${WORKSPACE}/.properties
    echo UPSTREAM_BUILD=${UPSTREAM_BUILD}      >> ${WORKSPACE}/.properties

    return 
}

# _setUpstream() {
#     if [[ "${BUILD_CAUSE_MANUALTRIGGER}" == true ]] ; then
#         debug "build was triggered manually, get last stable upstream"
#         
#     else
#         debug "build was triggered by upstream"
#     fi
# }

