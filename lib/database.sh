#!/bin/bash

LFS_CI_SOURCE_database='$Id$'

## @fn      databaseEventBuildStarted()
#  @brief   create an entry in the database table build_events for a started build
#  @param   <none>
#  @return  <none>
databaseEventBuildStarted() {
    requiredParameters LFS_CI_ROOT

    local branch=$(getLocationName)
    mustHaveLocationName

    local revision=$(cut -d" " -f 3 ${WORKSPACE}/revision_state.txt | sort -n -u | tail -n 1)
    mustHaveValue "${revision}" "revision from revision state file"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n ${label} -b ${branch} -r ${revision} -a build_started

    return
}

## @fn      databaseEventBuildFinished()
#  @brief   create an entry in the database table build_events for a finished build
#  @param   <none>
#  @return  <none>
databaseEventBuildFinished() {
    requiredParameters LFS_CI_ROOT

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n ${label} -a build_finished
    return
}

## @fn      databaseEventBuildFailed()
#  @brief   create an entry in the database table build_events for a failed build
#  @param   <none>
#  @return  <none>
databaseEventBuildFailed() {
    requiredParameters LFS_CI_ROOT

    local rc=$1

    # call only if test failed
    [[ ${rc} -eq 0 ]] || return 0

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n ${label} -a build_failed
    return
}

## @fn      databaseEventReleaseStarted()
#  @brief   create an entry in the database table build_events for a started release process
#  @param   <none>
#  @return  <none>
databaseEventReleaseStarted() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME
    local label=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n ${label} -a release_started
    return
}

## @fn      databaseEventReleaseFinished()
#  @brief   create an entry in the database table build_events for a finished release process
#  @param   <none>
#  @return  <none>
databaseEventReleaseFinished() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME
    local label=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n ${label} -a release_finished
    return
}

databaseEventTestStarted() {
    local label=$1
    local targetName=$2
    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n ${label} -c ${targetName} -a test_started
    return
}


databaseEventTestFinished() {
    local label=$1
    local targetName=$2
    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n ${label} -c ${targetName} -a test_finished
    return
}

