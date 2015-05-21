#!/bin/bash
## @file  database.sh
#  @brief handling of metrics to the database 
#
# conzept for events;
# all jobs are creating events for a build into the build_events table
# id | build_id | event_id | timestamp | job_name | build_number 
# --------------------------------------------------------------
# 0  |   1      |     1    |  now      | ABC      | 1
# ....
# --------------------------------------------------------------
# 
# the event_id is a reference to the event table
# id | product_name | task_name  | event_type | event_state 
# ---------------------------------------------------------- 
# 0  | LFS          | build      | build      | started     
# 0  | UBOOT        | build      | build      | started     
# 0  | LFS          | smoketest  | test       | started     
# 0  | LFS          | smoketest  | subtest    | started     
# 0  | LFS          | smoketest  | subtest    | finished    
# 0  | LFS          | smoketest  | subtest    | started     
# 0  | LFS          | smoketest  | subtest    | failed      
# 0  | LFS          | smoketest  | subtest    | unstable      
# 0  | LFS          | smoketest  | test       | failed      
# 0  | LFS          | smoketest  | package    | failed      
# 
# 0  | LFS          | targettest | test       | started     
# 0  | LFS          | targettest | subtest    | started     
# 0  | LFS          | targettest | subtest    | failed      
# 0  | LFS          | targettest | test       | failed      
# ----------------------------------------------------------

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

databaseEventBuildFinished() {
    _storeEvent build_finished
    return
}

databaseEventOtherStarted() {
    _storeEvent other_started $1
    return
}
databaseEventOtherFinished() {
    _storeEvent other_finished $1
    return
}
databaseEventOtherFailed() {
    _storeEvent other_failed $1
    return
}
databaseEventOtherUnstable() {
    _storeEvent other_unstable $1
    return
}

# databaseEventChangeEventTypeToUnstable() {
#     _storeEvent changeEventTypeToUnstable ...
#     return
# }

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
    return
}
## @fn      databaseEventTestFailed()
#  @brief   create an entry in the database table build_events for a failed test 
#  @param   <none>
#  @return  <none>
databaseEventTestFailed() {
    _storeEvent test_failed
    return
}
## @fn      databaseEventPackageStarted()
#  @brief   create an entry in the database table build_events for a started package process
#  @param   <none>
#  @return  <none>
databaseEventPackageStarted() {
    _storeEvent package_started
    return
}

## @fn      databaseEventPackageFinished()
#  @brief   create an entry in the database table build_events for a finished package process
#  @param   <none>
#  @return  <none>
databaseEventPackageFinished() {
    _storeEvent package_finished
    return
}

## @fn      databaseEventPackageFailed()
#  @brief   create an entry in the database table build_events for a failed package process
#  @param   <none>
#  @return  <none>
databaseEventPackageFailed() {
    _storeEvent package_failed
    return
}

## @fn      databaseEventSubBuildStarted()
#  @brief   create an entry in the database table build_events for a started subtest process
#  @param   <none>
#  @return  <none>
databaseEventSubTestStarted() {
    local taskName=""
    if [[ ${JOB_NAME} =~ ^Test- ]] ; then
        taskName=test
    fi
    _storeEvent subtest_started ${taskName}
    return
}

## @fn      databaseEventSubBuildFinished()
#  @brief   create an entry in the database table build_events for a finished subtest process
#  @param   <none>
#  @return  <none>
databaseEventSubTestFinished() {
    local taskName=""
    if [[ ${JOB_NAME} =~ ^Test- ]] ; then
        taskName=test
    fi
    _storeEvent subtest_finished ${taskName}
    return
}

## @fn      databaseEventSubBuildFailed()
#  @brief   create an entry in the database table build_events for a failed subtest process
#  @param   <none>
#  @return  <none>
databaseEventSubTestFailed() {
    local taskName=""
    if [[ ${JOB_NAME} =~ ^Test- ]] ; then
        taskName=test
    fi
    _storeEvent subtest_failed ${taskName}
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

    local productName=$(getProductNameFromJobName)
    if [[ ${JOB_NAME} =~ Test- ]] ; then
        productName=LFS
    fi
    mustHaveValue "${productName}" "product name"

    local taskName=$(getTaskNameFromJobName)
    case $1 in
        --*) true ;; 
        # strange behavour.....
        *)   [[ $1 ]] && taskName=$1 ; shift ;;
    esac
    mustHaveValue "${taskName}" "task name"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    execute -i ${LFS_CI_ROOT}/bin/newEvent    \
                --buildName=${label}          \
                --action=${eventName}         \
                --jobName=${JOB_NAME}         \
                --buildNumber=${BUILD_NUMBER} \
                --productName=${productName}  \
                --taskName=${taskName,,}      \
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
