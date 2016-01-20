#!/bin/bash
## @file  database.sh
#  @brief handling of metrics to the database 
#
# conzept for events;
# all jobs are creating events for a build into the build_events table
# <pre>
# id | build_id | event_id | timestamp | job_name | build_number 
# --------------------------------------------------------------
# 0  |   1      |     1    |  now      | ABC      | 1
# ....
# --------------------------------------------------------------
# </pre>
# 
# the event_id is a reference to the event table
# <pre>
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
# </pre>

# difference between event_type and task_name:

# event_type can be
# * build or subbuild for a build job, which is compiling software
# * test or subtest for a test job, which is testing software
# * package for the package job
# * release for the release job
# * other for other jobs, which are not listed above

# task_name can be more. In most of the cases, task_name is the same as event_type,
# but for test, it is different. There are several tests jobs, with different 
# task_names: smoketest regulartest test testnonblocking stabilitytest ...
# 

LFS_CI_SOURCE_database='$Id$'

## @fn      eventBuildStarted()
#  @brief   create an entry in the database table build_events for a started build
#  @param   <none>
#  @return  <none>
eventBuildStarted() {
    requiredParameters LFS_CI_ROOT JOB_NAME BUILD_NUMBER

    local branchName=$(getBranchName)
    mustHaveBranchName

    local buildDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} ${BUILD_NUMBER})
    local revision=$(runOnMaster cat ${buildDirectory}/revisionstate.xml | cut -d" " -f 3 | sort -n -u | tail -n 1)
    mustHaveValue "${revision}" "revision from revision state file"

    storeEvent build_started --revision=${revision} --branchName=${branchName}
    return
}

## @fn      eventOtherStarted()
#  @brief   create an entry in the database table build_events for a started "other" event
#  @param   {eventName} name of the event
#  @return  <none>
eventOtherStarted() {
    storeEvent other_started $1
    return
}

## @fn      eventOtherFinished()
#  @brief   create an entry in the database table build_events for a finished "other" event
#  @param   {eventName} name of the event
#  @return  <none>
eventOtherFinished() {
    storeEvent other_finished $1
    return
}

## @fn      eventOtherFailed()
#  @brief   create an entry in the database table build_events for a failed "other" event
#  @param   {eventName} name of the event
#  @return  <none>
eventOtherFailed() {
    storeEvent other_failed $1
    return
}

## @fn      eventOtherUnstable()
#  @brief   create an entry in the database table build_events for a unstable "other" event
#  @param   <none>
#  @return  <none>
eventOtherUnstable() {
    storeEvent other_unstable $1
    return
}

## @fn      eventSubTestStarted()
#  @brief   create an entry in the database table build_events for a started subtest process
#  @param   <none>
#  @return  <none>
eventSubTestStarted() {
    local taskName=""
    if [[ ${JOB_NAME} =~ ^Test- ]] ; then
        taskName=test
    fi
    storeEvent subtest_started ${taskName}
    return
}

## @fn      eventSubTestFinished()
#  @brief   create an entry in the database table build_events for a finished subtest process
#  @param   <none>
#  @return  <none>
eventSubTestFinished() {
    local taskName=""
    if [[ ${JOB_NAME} =~ ^Test- ]] ; then
        taskName=test
    fi
    storeEvent subtest_finished ${taskName}
    return
}

## @fn      eventSubTestFailed()
#  @brief   create an entry in the database table build_events for a failed subtest process
#  @param   <none>
#  @return  <none>
eventSubTestFailed() {
    local taskName=""
    if [[ ${JOB_NAME} =~ ^Test- ]] ; then
        taskName=test
    fi
    storeEvent subtest_failed ${taskName}
    return
}

## @fn      storeEvent()
#  @brief   internal function: store the event in the database table build_events  
#  @param   {eventName}    name of the event
#  @param   {targetName}   name of the target
#  @param   {opts}         additional (optional) options for newEvent.
#                          only use this option, if really required!
#  @return  <none>
storeEvent() {
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

    # TODO 2016-01-19 demx2fk3 workaround for LRC. This should be done differently
    if [[ -z ${taskName} && ${JOB_NAME} =~ ^Test- ]] ; then
        taskName=test
    fi

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
#  @param   {jobName}          name of the jenkins job
#  @param   {buildNumer}       build number of the jenkins job
#  @return  <none>
databaseTestResults() {
    local labelName=$1
    local testSuiteName=$2
    local targetName=$3
    local targetType=$4
    local resultFile=$5
    local jobName=$6
    local buildNumber=$7

    info "adding metrics for ${labelName}, ${testSuiteName}, ${targetName}/${targetType}"
    execute ${LFS_CI_ROOT}/bin/newTestResults   \
            --buildName=${labelName}               \
            --resultFile=${resultFile}             \
            --testSuiteName=${testSuiteName}       \
            --targetName=${targetName}             \
            --targetType=${targetType}             \
            --jobName=${jobName}                   \
            --buildNumber=${buildNumber} 

    return
}

## @fn      databaseTestCaseResults()
#  @brief   add new test case results from a test job into the database
#  @param   {labelName}        name of the label
#  @param   {testSuiteName}    name of the test suite
#  @param   {targetName}       name of the target
#  @param   {targetType}       type of the target
#  @param   {resultFile}       file with results
#  @param   {jobName}          name of the jenkins job
#  @param   {buildNumer}       build number of the jenkins job
#  @return  <none>
databaseTestCaseResults() {
    local labelName=$1
    local testSuiteName=$2
    local targetName=$3
    local targetType=$4
    local resultFile=$5
    local jobName=$6
    local buildNumber=$7

    info "adding metrics for ${labelName}, ${testSuiteName}, ${targetName}/${targetType}"
    execute ${LFS_CI_ROOT}/bin/newTestCaseResults \
            --buildName=${labelName}                 \
            --resultFile=${resultFile}               \
            --testSuiteName=${testSuiteName}         \
            --targetName=${targetName}               \
            --targetType=${targetType}               \
            --jobName=${jobName}                     \
            --buildNumber=${buildNumber} 

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

## @fn      mustHaveDatabaseCredentials()
#  @brief   ensures, that the database credentials are set
#  @param   <none>
#  @return  <none>
mustHaveDatabaseCredentials() {
    [[ -z ${dbName} ]] && dbName=$(getConfig MYSQL_db_name)
    mustHaveValue "${dbName}" "dbName"
    [[ -z ${dbPort} ]] && dbPort=$(getConfig MYSQL_db_port)
    mustHaveValue "${dbName}" "dbPort"
    [[ -z ${dbUser} ]] && dbUser=$(getConfig MYSQL_db_username)
    mustHaveValue "${dbName}" "dbUser"
    [[ -z ${dbPass} ]] && dbPass=$(getConfig MYSQL_db_password)
    mustHaveValue "${dbName}" "dbPass"
    [[ -z ${dbHost} ]] && dbHost=$(getConfig MYSQL_db_hostname)
    mustHaveValue "${dbName}" "dbHost"

    if [[ -z ${mysql_cli} ]] ; then
        mysql_cli="mysql -u${dbUser} -h${dbHost}"
        [[ ${dbPass} ]] && mysql_cli="${mysql_cli} --password=${dbPass}"
    fi
    mustHaveValue "${mysql_cli}" "mysql_cli"

    return
}

