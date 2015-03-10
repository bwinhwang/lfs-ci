#!/bin/bash
## @file  database.sh
#  @brief handling of metrics to the database 

LFS_CI_SOURCE_database='$Id$'

## @fn      databaseEventBuildStarted()
#  @brief   create an entry in the database table build_events for a started build
#  @param   <none>
#  @return  <none>
databaseEventBuildStarted() {
    requiredParameters LFS_CI_ROOT JOB_NAME BUILD_NUMBER

    local branchName=$(getLocationName)
    mustHaveLocationName

    local buildDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} ${BUILD_NUMBER})
    local revision=$(runOnMaster cat ${buildDirectory}/revisionstate.xml | cut -d" " -f 3 | sort -n -u | tail -n 1)
    mustHaveValue "${revision}" "revision from revision state file"

    _storeEvent build_started --revision=${revision} --branchName=${branchName}
    return
}

databaseEventBuildFailed() {
    _storeEvent build_failed
    return
}

## @fn      databaseEventSubBuildFinished()
#  @brief   create an entry in the database table build_events for a finished build
#  @param   <none>
#  @return  <none>
databaseEventSubBuildStarted() {
    _storeEvent subbuild_started
    return
}

databaseEventSubBuildFinished() {
    _storeEvent subbuild_finished
    return
}

## @fn      databaseEventSubBuildFailed()
#  @brief   create an entry in the database table build_events for a failed build
#  @param   <none>
#  @return  <none>
databaseEventSubBuildFailed() {
    _storeEvent subbuild_failed
    return
}

## @fn      databaseEventReleaseStarted()
#  @brief   create an entry in the database table build_events for a started release process
#  @param   <none>
#  @return  <none>
databaseEventReleaseStarted() {
    _storeEvent release_started
    return
}

## @fn      databaseEventReleaseFinished()
#  @brief   create an entry in the database table build_events for a finished release process
#  @param   <none>
#  @return  <none>
databaseEventReleaseFinished() {
    _storeEvent release_finished
    return
}

databaseEventSubTestStarted() {
    local targetName=$1
    local targetType=$2
    _storeEvent "subtest_started" ${targetName} ${targetType}
    return
}


databaseEventSubTestFinished() {
    local targetName=$1
    local targetTYpe=$2
    _storeEvent "subtest_finished" ${targetName} ${targetType}
    return
}

databaseEventSubTestFailed() {
    local targetName=$1
    local targetTYpe=$2
    _storeEvent "subtest_failed" ${targetName} ${targetType}
    return
}

_storeEvent() {
    requiredParameters LFS_CI_ROOT JOB_NAME BUILD_NUMBER

    local eventName=$1
    mustHaveValue "${eventName}" "event name"
    shift

    local targetName=$1
    shift

    local targetType=$1
    shift

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    if [[ -z ${targetName} ]] ; then
        targetName=$(getSubTaskNameFromJobName)
    fi
    mustHaveValue "${targetName}" "target name"

    if [[ -z ${targetType} ]] ; then
        targetType=$(getTargetBoardName)
    fi
    mustHaveValue "${targetType}" "target type"

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl \
                --buildName=${label}               \
                --action=${eventName}              \
                --jobName=${JOB_NAME}              \
                --buildNumber=${BUILD_NUMBER}      \
                --targetName=${targetName:-host}   \
                --targetType=${targetType:-other}  \
                $@

    return
}

databaseAddNewCommits() {
    requiredParameters JOB_NAME BUILD_NUMBER

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} ${BUILD_NUMBER} changelog.xml

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --action=new_svn_commits --changelog=${WORKSPACE}/changelog.xml

    return
}

databaseTestResults() {
    local label=$1
    local testSuiteName=$2
    local targetName=$3
    local targetType=$4
    local resultFile=$5

    info "adding metrics for ${label}, ${testSuiteName}, ${targetName}/${targetType}"
    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl \
            --action=new_test_result               \
            --buildName=${label}                   \
            --resultFile=${resultFile}             \
            --testSuiteName=${testSuiteName}       \
            --targetName=${targetName}             \
            --targetType=${targetType} 

    return
}

addTestResultsToMetricDatabase() {
    local resultFileXml=${1}
    local baselineName=${2}
    local testSuite=${3}
    local targetName=${4}
    local targetType=${5}

    # store results in metric database
    info "storing result numbers in metric database"
    local resultFile=$(createTempFile)
    local test_total=$(grep '<testcase ' ${resultFileXml} | wc -l)
    local test_failed=$(grep '<failure>' ${resultFileXml} | wc -l)
    printf "test_failed;%d\ntest_total;%d" ${test_failed} ${test_total} > ${resultFile}
    rawDebug ${resultFile}

    databaseTestResults ${baselineName} \
                        ${testSuite}    \
                        ${targetName}   \
                        ${targetType}   \
                        ${resultFile}
    return
}
