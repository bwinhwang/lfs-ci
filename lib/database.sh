#!/bin/bash

LFS_CI_SOURCE_database='$Id$'

## @fn      databaseEventBuildStarted()
#  @brief   create an entry in the database table build_events for a started build
#  @param   <none>
#  @return  <none>
databaseEventBuildStarted() {
    requiredParameters LFS_CI_ROOT JOB_NAME BUILD_NUMBER

    local branch=$(getLocationName)
    mustHaveLocationName

    local buildDirectory=$(getBuildDirectoryOnMaster ${JOB_NAME} ${BUILD_NUMBER})
    local revision=$(runOnMaster cat ${buildDirectory}/revisionstate.xml | cut -d" " -f 3 | sort -n -u | tail -n 1)
    mustHaveValue "${revision}" "revision from revision state file"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    mustHaveValue ${label} "label name"

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --branchName=${branch} --revision=${revision} --action=build_started

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

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --action=build_finished
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

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --action=build_failed
    return
}

## @fn      databaseEventReleaseStarted()
#  @brief   create an entry in the database table build_events for a started release process
#  @param   <none>
#  @return  <none>
databaseEventReleaseStarted() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME
    local label=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --action=release_started
    return
}

## @fn      databaseEventReleaseFinished()
#  @brief   create an entry in the database table build_events for a finished release process
#  @param   <none>
#  @return  <none>
databaseEventReleaseFinished() {
    requiredParameters LFS_PROD_RELEASE_CURRENT_TAG_NAME
    local label=${LFS_PROD_RELEASE_CURRENT_TAG_NAME}

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --action=release_finished
    return
}

databaseEventTestStarted() {
    local label=$1
    local targetName=$2
    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --comment=${targetName} --action=test_started
    return
}


databaseEventTestFinished() {
    local label=$1
    local targetName=$2
    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=${label} --comment=${targetName} --action=test_finished
    return
}

databaseTestResults() {
    local label=$1
    local testSuiteName=$2
    local targetName=$3
    local targetType=$4
    local resultFile=$5

    execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl \
            --action=new_test_result               \
            --buildName=${label}                            \
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
    local targetTYpe=${5}

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
                        ${targetTYpe}   \
                        ${resultFile}

    return
}