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

## @fn      databaseEventBuildFailed()
#  @brief   create an entry in the database table build events for a failed build
#  @param   <none>
#  @return  <none>
databaseEventBuildFailed() {
    _storeEvent build_failed
    return
}

## @fn      databaseEventSubBuildFinished()
#  @brief   create an entry in the database table build_events for a started build
#  @param   <none>
#  @return  <none>
databaseEventSubBuildStarted() {
    _storeEvent subbuild_started
    return
}

## @fn      databaseEventBuildFinished()
#  @brief   create an entry in the database table build_events for a finished build
#  @param   <none>
#  @return  <none>
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

## @fn      databaseEventTestStarted()
#  @brief   create an entry in the database table build_events for a started test 
#  @param   <none>
#  @return  <none>
databaseEventTestStarted() {
    _storeEvent test_started
}
## @fn      databaseEventTestFailed()
#  @brief   create an entry in the database table build_events for a failed test 
#  @param   <none>
#  @return  <none>
databaseEventTestFailed() {
    _storeEvent test_failed
}
## @fn      databaseEventPackageStarted()
#  @brief   create an entry in the database table build_events for a started package process
#  @param   <none>
#  @return  <none>
databaseEventPackageStarted() {
    _storeEvent package_started
}

## @fn      databaseEventPackageFinished()
#  @brief   create an entry in the database table build_events for a finished package process
#  @param   <none>
#  @return  <none>
databaseEventPackageFinished() {
    _storeEvent package_finished
}

## @fn      databaseEventPackageFailed()
#  @brief   create an entry in the database table build_events for a failed package process
#  @param   <none>
#  @return  <none>
databaseEventPackageFailed() {
    _storeEvent package_failed
}

## @fn      databaseEventSubBuildStarted()
#  @brief   create an entry in the database table build_events for a started subtest process
#  @param   <none>
#  @return  <none>
databaseEventSubTestStarted() {
    _storeEvent subtest_started 
    return
}

## @fn      databaseEventSubBuildFinished()
#  @brief   create an entry in the database table build_events for a finished subtest process
#  @param   <none>
#  @return  <none>
databaseEventSubTestFinished() {
    _storeEvent subtest_finished
    return
}

## @fn      databaseEventSubBuildFailed()
#  @brief   create an entry in the database table build_events for a failed subtest process
#  @param   <none>
#  @return  <none>
databaseEventSubTestFailed() {
    _storeEvent subtest_failed 
    return
}

## @fn      _storeEvent()
#  @brief   internal function: store the event in the database table build_events  
#  @param   {eventType}    type of the event
#  @param   {targetName}   name of the target
#  @param   {targetType}   type of the target
#  @return  <none>
_storeEvent() {
    requiredParameters LFS_CI_ROOT JOB_NAME BUILD_NUMBER

    local eventName=$1
    mustHaveValue "${eventName}" "event name"
    shift

    # fixme
    local targetName=""
    local targetType=""
    if [[ ${JOB_NAME} =~ Test- ]] ; then
        targetName=$(_reserveTarget)
        targetType=$(getConfig LFS_CI_uc_test_target_type_mapping -t jobName:${targetType})
    else
        # target type: FSM-r2, FSM-r3, FSM-r4, LRC, host
        targetName=$(getSubTaskNameFromJobName)
        targetType=$(getTargetBoardName)
    fi
    mustHaveValue "${targetName}" "target name"
    mustHaveValue "${targetType}" "target type"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    execute -i ${LFS_CI_ROOT}/bin/newEvent         \
                --buildName=${label}               \
                --action=${eventName}              \
                --jobName=${JOB_NAME}              \
                --buildNumber=${BUILD_NUMBER}      \
                --targetName=${targetName:-host}   \
                --targetType=${targetType:-other}  \
                $@

    return
}

## @fn      databaseAddNewCommits()
#  @brief   adds all new commits from the build log into the database table subverion_commits 
#  @param   <none>
#  @return  <none>
databaseAddNewCommits() {
    requiredParameters JOB_NAME BUILD_NUMBER

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    copyFileFromBuildDirectoryToWorkspace ${JOB_NAME} ${BUILD_NUMBER} changelog.xml

    execute -i ${LFS_CI_ROOT}/bin/newSubversionCommits --buildName=${label} --changelog=${WORKSPACE}/changelog.xml

    return
}

## @fn      databaseTestResults()
#  @brief   add new test results from a test job into the database
#  @param   {labelName}        name of the label
#  @param   {testSuiteName}    name of the test suite
#  @param   {targetName}       name of the target
#  @param   {targetType}       type of the target
#  @param   {resultFile}       file with results
#  @return  <none>
databaseTestResults() {
    local labelName=$1
    local testSuiteName=$2
    local targetName=$3
    local targetType=$4
    local resultFile=$5

    info "adding metrics for ${labelName}, ${testSuiteName}, ${targetName}/${targetType}"
    execute -i ${LFS_CI_ROOT}/bin/newTestResults   \
            --buildName=${labelName}               \
            --resultFile=${resultFile}             \
            --testSuiteName=${testSuiteName}       \
            --targetName=${targetName}             \
            --targetType=${targetType} 

    return
}

## @fn      addTestResultsToMetricDatabase()
#  @brief   add test results into database
#  @param   {resultFile}       file with results
#  @param   {labelName}        name of the label
#  @param   {testSuiteName}    name of the test suite
#  @param   {targetName}       name of the target
#  @param   {targetType}       type of the target
#  @return  <none>
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
