#!/bin/bash
## @file    uc_collect_metrics.sh
#  @brief   usecase collect metrics - collect the metrics from the build and test jobs and store them into the database
#  @details naming: 
#           - LFS_CI_-_trunk_-_Test_-_collect_metrics
#  
#  The usecase is executed after the test jobs, no matter if they were successfull or not.
#  The usecase collects all the metrics from the build and test jobs and stores them into the database.
#  Collected metrics:
#  - Build jobs
#    - duration
#    - compiler warnings
#  - Package jobs
#    - duration
#  - Test jobs
#    - duration
#    - failed TCs
#    - skipped TCs
#    - total TCs
#  - From artifacts of test jobs
#    - all metrics, which are stored in files call <testsuite>-metrics-database-values.txt

[[ -z ${LFS_CI_SOURCE_common}    ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_database}  ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_test_collect_metrics()
#  @brief   run the usecase collect metrics (legacy function)
#  @todo    migrate to new usecase call concept and remove this function
#  @param   <none>
#  @return  <none>
ci_job_test_collect_metrics() {
    usecase_LFS_COLLECT_METRICS
    info "usecase collect metrics done (legacy)"
    return
}

## @fn      usecase_LFS_COLLECT_METRICS()
#  @brief   run the usecase collect metrics 
#  @param   <none>
#  @return  <none>
usecase_LFS_COLLECT_METRICS() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci

    collectMetricsFromBuildJobs
    collectMetricsFromPackageJob

    local artifactsPath=bld/bld-test-artifacts
    local artifactsFilter="test"
    collectMetricsFromTestJobs ${artifactsPath} ${artifactsFilter}

    info "usecase collect metrics done"
    return
}

## @fn      usecase_LFS_COLLECT_REGULARTEST_METRICS()
#  @brief   run the usecase collect regulartest metrics 
#  @param   <none>
#  @return  <none>
usecase_LFS_COLLECT_REGULARTEST_METRICS() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci

    local artifactsPath=bld/bld-test-artifacts
    local artifactsFilter="test"
    collectMetricsFromTestJobs ${artifactsPath} ${artifactsFilter}

    info "usecase collect RegularTest metrics done"
    return
}


## @fn      usecase_LFS_COLLECT_UNITTEST_METRICS()
#  @brief   run the usecase collect regulartest metrics 
#  @param   <none>
#  @return  <none>
usecase_LFS_COLLECT_UNITTEST_METRICS() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci

    for target in fsmr3 fsmr4
    do
        # unfortunately, the unittest jobs have the target name in the artifacts path
        # TODO: in principle it should be possible to do this with only one cycle. Either, the name of the
        # bld-unittests-* directory has to be changed or it should be made possible to use wildcards here
        local artifactsPath=bld/bld-unittests-${target}_fsmddal
        local artifactsFilter="unittests"
        collectMetricsFromTestJobs ${artifactsPath} ${artifactsFilter}
    done

    info "usecase collect UNITTEST metrics done"
    return
}



## @fn      collectMetricsFromBuildJobs()
#  @brief   collect the metrics of a build job and store them into the database
#  @details all data from a build job (and subbuild) will be collected and stored
#           in the database. 
#  @param   <none>
#  @return  <none>
collectMetricsFromBuildJobs() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local buildJobName=$(getBuildJobNameFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    local buildBuildNumber=$(getBuildBuildNumberFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    info "build job ${buildJobName} ${buildBuildNumber}"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    # we didn't get information about the build job => early exit
    [[ -z "${buildJobName}" ]] && return

    # analysing compiler warnings of build jobs
    local downStreamData=$(getDownStreamProjectsData ${buildJobName} ${buildBuildNumber})
    for line in ${downStreamData} ; do
        local buildNumber=$(cut -d: -f1 <<< ${line})
        local jobName=$(cut -d: -f3 <<< ${line})
        local state=$(cut -d: -f2 <<< ${line})

        [[ ${jobName} =~ FSMDDALpdf ]] && continue
        [[ ${state}   =~ NOT_BUILT  ]] && continue

        # build duration
        copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} build.xml
        mv ${WORKSPACE}/build.xml ${workspace}/${jobName}_build.xml

        # compiler warnings, results of compiler warnings are also in build.xml (very nice!!)
        local resultFile=$(createTempFile)
        local duration=$(${LFS_CI_ROOT}/bin/xpath -q -e '/build/duration/node()' ${workspace}/${jobName}_build.xml)
        printf "duration;%s\n" ${duration} >> ${resultFile}

        for key in numberOfModules numberOfWarnings numberOfNewWarnings numberOfFixedWarnings delta lowDelta \
                   normalDelta highDelta lowWarnings normalWarnings highWarnings zeroWarningsSinceBuild \
                   zeroWarningsSinceDate zeroWarningsHighScore isZeroWarningsHighscore highScoreGap \
                   successfulSinceBuild successfulSinceDate successfulHighscore isSuccessfulHighscore \
                   successfulHighScoreGap isSuccessfulStateTouched referenceBuild 
        do
            local value=$(${LFS_CI_ROOT}/bin/xpath -q -e "/build/actions/hudson.plugins.warnings.AggregatedWarningsResultAction/result/${key}/node()" ${workspace}/${jobName}_build.xml)
            printf "compilerWarnings_${key};%s\n" ${value} >> ${resultFile}
        done

        rawDebug ${resultFile}

        databaseTestResults ${label} "Build" ${jobName} "host" ${resultFile} ${jobName} ${buildNumber}
    done
    
    return
}

## @fn      collectMetricsFromTestJobs()
#  @brief   collect all metrics from a test job (and sub tests) and store them into the database
#  @param   {artifactsPath}    path in workspace where artifacts can be found
#  @param   {artifactsFilter}  filter for selecting artifacts
#  @return  <none>
collectMetricsFromTestJobs() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 

    local artifactsPath=$1
    local artifactsFilter=$2
    info "starting collectMetricsFromTestJobs with artifactsPath=${artifactsPath} and artifactsFilter=${artifactsFilter}"
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    cd ${workspace}

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}
    info "label name is ${label}"

    local testJobData=$(getDownStreamProjectsData ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    info "testJobData=${testJobData}"
    for line in ${testJobData} ; do
        info ${line}
        local buildNumber=$(cut -d: -f1 <<< ${line})
        local jobName=$(cut -d: -f3 <<< ${line})
        local state=$(cut -d: -f2 <<< ${line})
        info "checking job ${jobName}"

        # no need to collect the metrics for some types of test jobs
        # (dummy jobs) and for some states...
        [[ "${jobName}" =~ _Test$             ]] && continue
        [[ "${jobName}" =~ makingTest$        ]] && continue
        [[ "${jobName}" =~ target$            ]] && continue
        [[ "${jobName}" =~ MakingTest_-_lcpa$ ]] && continue
        [[ "${jobName}" =~ excludefailures$   ]] && continue
        [[ "${jobName}" =~ _RegularTest$      ]] && continue
        [[ "${jobName}" =~ _CodeCoverage$     ]] && continue

        [[ "${state}"   = FAILURE   ]] && continue
        [[ "${state}"   = ABORTED   ]] && continue
        [[ "${state}"   = NOT_BUILT ]] && continue

        storeMetricsForTestJob    ${jobName} ${buildNumber}
        storeMetricsFromArtifacts ${jobName} ${buildNumber} ${artifactsPath} ${artifactsFilter}
    done

    return
}

## @fn      collectMetricsFromPackageJob()
#  @brief   collect all metrics of a package job and store them into the database
#  @param   <none>
#  @return  <none>
collectMetricsFromPackageJob() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 

    local packageJobName=$(getPackageJobNameFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    local packageBuildNumber=$(getPackageBuildNumberFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    info "package job ${packageJobName} ${packageBuildNumber}"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    # no need to collect metrics, if we don't get a package job => early exit
    [[ -z "${packageJobName}" ]] && return

    # get package duration
    copyFileFromBuildDirectoryToWorkspace ${packageJobName} ${packageBuildNumber} build.xml
    mv ${WORKSPACE}/build.xml ${workspace}/${packageJobName}_build.xml

    local resultFile=$(createTempFile)
    local duration=$(${LFS_CI_ROOT}/bin/xpath -q -e '/build/duration/node()' ${workspace}/${packageJobName}_build.xml)
    printf "duration;%s\n" ${duration} >> ${resultFile}
    databaseTestResults ${label} "Package" ${packageJobName} "host" ${resultFile} ${packageJobName} ${packageBuildNumber}

    return
}


## @fn      storeMetricsForTestJob()
#  @brief   store the metrics from the test job into the database
#  @param   {jobName}        name of the job
#  @param   {buildNumber}    number of the build
#  @return  <none>
storeMetricsForTestJob() {
    requiredParameters WORKSPACE LFS_CI_ROOT

    local jobName=${1}
    mustHaveValue "${jobName}" "job name"

    local buildNumber=${2}
    mustHaveValue "${buildNumber}" "build number"

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} junitResult.xml
    copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} build.xml
    mv ${WORKSPACE}/junitResult.xml ${workspace}/${jobName}_junitResult.xml
    mv ${WORKSPACE}/build.xml       ${workspace}/${jobName}_build.xml

    # try to figure out, if this was a FMON test or a making test test run
    local testSuiteName=$(xpath -q -e '/result/suites/suite/name/node()' ${workspace}/${jobName}_junitResult.xml)

    local testSuiteType="makingTest"
    if [[ "${testSuiteName}" = FSMJENKINS ]] ; then
        debug "looks like a FMON test"
        testSuiteType="FMON"
    fi
    debug "testSuiteType ${testSuiteType}"

    local testTotal=$(${LFS_CI_ROOT}/bin/xpath   -q -e '/build/actions/hudson.tasks.junit.TestResultAction/totalCount/node()' ${workspace}/${jobName}_build.xml)
    local testFailed=$(${LFS_CI_ROOT}/bin/xpath  -q -e '/build/actions/hudson.tasks.junit.TestResultAction/failCount/node()'  ${workspace}/${jobName}_build.xml)
    local testSkipped=$(${LFS_CI_ROOT}/bin/xpath -q -e '/build/actions/hudson.tasks.junit.TestResultAction/skipCount/node()'  ${workspace}/${jobName}_build.xml)
    local duration=$(${LFS_CI_ROOT}/bin/xpath    -q -e '/build/duration/node()' ${workspace}/${jobName}_build.xml)

    local resultFile=$(createTempFile)
    printf "test_failed;%s\ntest_total;%s\ntest_skipped;%s\nduration;%s" \
        ${testFailed} ${testTotal} ${testSkipped} ${duration} > ${resultFile}

    rawDebug ${resultFile}

    export jobName
    local targetType=$(getConfig LFS_CI_uc_test_target_type_mapping)
    mustHaveValue "${targetType}" "target type"

    databaseTestResults     ${label} ${testSuiteType} ${jobName} "${targetType}" ${resultFile} ${jobName} ${buildNumber}
    databaseTestCaseResults ${label} ${testSuiteType} ${jobName} "${targetType}" ${workspace}/${jobName}_junitResult.xml ${jobName} ${buildNumber}

    return
}

## @fn      storeMetricsFromArtifacts()
#  @brief   store the metrics, which are included in the artifacts into the database
#  @param   {jobName}          name of the job
#  @param   {buildNumber}      number of the build
#  @param   {artifactsPath}    path in workspace where artifacts can be found
#  @param   {artifactsFilter}  filter for selecting artifacts
#  @return  <none>
storeMetricsFromArtifacts() {
    local jobName=$1
    mustHaveValue "${jobName}" "job name"

    local buildNumber=$2
    mustHaveValue "${buildNumber}" "build number"

    local artifactsPath=$3
    mustHaveValue "${artifactsPath}" "artifacts path"

    local artifactsFilter=$4
    mustHaveValue "${artifactsFilter}" "artifacts filter"

    info "starting storeMetricsFromArtifacts with artifactsPath=${artifactsPath} and artifactsFilter=${artifactsFilter}"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    debug "cleanup artifacts from test in ${artifactsPath} ..."
    execute rm -rf ${workspace}/${artifactsPath}
    debug "copy artifacts from ${jobName} ${buildNumber}..."
    copyArtifactsToWorkspace ${jobName} ${buildNumber} ${artifactsFilter} 

    [[ -d ${workspace}/${artifactsPath}/         ]] || return
    [[ -d ${workspace}/${artifactsPath}/results/ ]] || return

    for file in ${workspace}/${artifactsPath}/results/*-metrics-database-values.txt ; do
        [[ -e ${file} ]] || continue
        debug "adding values from ${file} to metrics database"

        local testSuiteType=$(basename ${file} | sed "s/-metrics-database-values.txt//g" )
        mustHaveValue "${testSuiteType}" "testSuiteType"

        export jobName
        local targetType=$(getConfig LFS_CI_uc_test_target_type_mapping)
        mustHaveValue "${targetType}" "target type"

        databaseTestResults ${label} ${testSuiteType} ${jobName} "${targetType}" ${file} ${jobName} ${buildNumber}

    done

    return
}
