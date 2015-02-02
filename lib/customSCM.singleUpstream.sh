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

    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"


    local upstreamProjectName=${UPSTREAM_PROJECT:-${TESTED_BUILD_JOBNAME}}
    local upstreamBuildNumber=${UPSTREAM_BUILD:-${TESTED_BUILD_NUMBER}}
    local server=$(getConfig jenkinsMasterServerHostName)
    local buildDirectory=$(getBuildDirectoryOnMaster ${upstreamProjectName} ${upstreamBuildNumber})


    if [[ -z ${upstreamProjectName} || -z ${upstreamBuildNumber} ]] ; then
        upstreamProjectName=$(getUpstreamProjectName)
        local buildPath=$(getBuildDirectoryOnMaster ${upstreamProjectName} lastSuccessfulBuild)
        upstreamBuildNumber=$(runOnMaster readlink ${buildPath}) 
        warning "didn't find the upstream build, using ${upstreamProjectName} / ${upstreamBuildNumber}"
    fi

    info "getting changelog.xml from ${buildDirectory} on ${server}"
    debug "ssh ${server} \"test -f ${buildDirectory}/changelog.xml && grep -q logentry ${buildDirectory}/changelog.xml && cat ${buildDirectory}/changelog.xml\" ${CHANGELOG}"
    ssh ${server} "test -f ${buildDirectory}/changelog.xml && grep -q logentry ${buildDirectory}/changelog.xml && cat ${buildDirectory}/changelog.xml" > ${CHANGELOG}

    # Fix empty changelogs:
    if [ ! -s "${CHANGELOG}" ] ; then
        echo -n "<log/>" >"${CHANGELOG}"
    fi

    rawDebug ${CHANGELOG}

    return
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details
#  @param   <none>
#  @return  <none>
actionCalculate() {

    local upstreamProjectName=${UPSTREAM_PROJECT:-${TESTED_BUILD_JOBNAME}}
    local upstreamBuildNumber=${UPSTREAM_BUILD:-${TESTED_BUILD_NUMBER}}

    info "upstreamProjectName ${upstreamProjectName} / upstreamBuildNumber ${upstreamBuildNumber}"
    if [[ -z ${upstreamProjectName} || -z ${upstreamBuildNumber} ]] ; then
        upstreamProjectName=$(getUpstreamProjectName)
        local buildPath=$(getBuildDirectoryOnMaster ${upstreamProjectName} lastSuccessfulBuild)
        upstreamBuildNumber=$(runOnMaster readlink ${buildPath}) 
        warning "didn't find the upstream build, using ${upstreamProjectName} / ${upstreamBuildNumber}"
        # exit 1
    fi

    debug "creating revision state file ${REVISION_STATE_FILE}"
    echo ${upstreamProjectName} >  "${REVISION_STATE_FILE}"
    echo ${upstreamBuildNumber} >> "${REVISION_STATE_FILE}"

    # upstream handling if missing
    debug "storing upstream info in .properties"
    echo UPSTREAM_PROJECT=${upstreamProjectName} > ${WORKSPACE}/.properties
    echo UPSTREAM_BUILD=${upstreamBuildNumber}   >> ${WORKSPACE}/.properties

    rawDebug ${WORKSPACE}/.properties

    return 
}
