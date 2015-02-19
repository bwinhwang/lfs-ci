#!/bin/bash
## @file  uc_test
#  @brief the test usecase

[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_database}  ]] && source ${LFS_CI_ROOT}/lib/database.sh

ci_job_test_collect_metrics() {
    usecase_LFS_COLLECT_METRICS
}

usecase_LFS_COLLECT_METRICS() {
    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD 

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    cd ${workspace}

    local buildJobName=$(getBuildJobNameFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    local buildBuildNumber=$(getBuildBuildNumberFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    info "build job ${buildJobName} ${buildBuildNumber}"

    copyArtifactsToWorkspace ${buildJobName} ${buildBuildNumber} fsmci

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    # TODO: demx2fk3 2015-01-13 enable me
    # setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}
    info "label name is ${label}"

    local testJobData=$(getDownStreamProjectsData ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    for line in ${testJobData} ; do
        info ${line}
        local buildNumber=$(cut -d: -f1 <<< ${line})
        local jobName=$(cut -d: -f3 <<< ${line})
        local state=$(cut -d: -f2 <<< ${line})

        [[ "${jobName}" =~ _Test$             ]] && continue
        [[ "${jobName}" =~ makingTest$        ]] && continue
        [[ "${jobName}" =~ target$            ]] && continue
        [[ "${jobName}" =~ MakingTest_-_lcpa$ ]] && continue

        [[ "${state}"   = FAILURE   ]] && continue
        [[ "${state}"   = ABORTED   ]] && continue
        [[ "${state}"   = NOT_BUILT ]] && continue

        storeMetricsForTestJob    ${jobName} ${buildNumber}
        storeMetricsFromArtifacts ${jobName} ${buildNumber}

    done

    # analysing compiler warnings of build jobs
    local downStreamData=$(getDownStreamProjectsData ${buildJobName} ${buildBuildNumber})
    for line in ${downStreamData} ; do
        debug ${line}
        local buildNumber=$(cut -d: -f1 <<< ${line})
        local jobName=$(cut -d: -f3 <<< ${line})
        local state=$(cut -d: -f2 <<< ${line})

        [[ ${jobName} =~ FSMDDALpdf ]] && continue

        # compiler warnings, results of compiler warnings are also in build.xml (very nice!!)
        # copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} analysis.xml
        # mv ${WORKSPACE}/analysis.xml ${workspace}/${jobName}_analysis.xml

        # build duration
        copyFileFromBuildDirectoryToWorkspace ${jobName} ${buildNumber} build.xml
        mv ${WORKSPACE}/build.xml ${workspace}/${jobName}_build.xml

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

        databaseTestResults ${label} "Build" ${jobName} "host" ${resultFile}
    done

    local packageJobName=$(getPackageJobNameFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    local packageBuildNumber=$(getPackageBuildNumberFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    info "package job ${packageJobName} ${packageBuildNumber}"
    # get package duration
    copyFileFromBuildDirectoryToWorkspace ${packageJobName} ${packageBuildNumber} build.xml
    mv ${WORKSPACE}/build.xml ${workspace}/${packageJobName}_build.xml

    local resultFile=$(createTempFile)
    local duration=$(${LFS_CI_ROOT}/bin/xpath -q -e '/build/duration/node()' ${workspace}/${packageJobName}_build.xml)
    printf "duration;%s\n" ${duration} >> ${resultFile}
    databaseTestResults ${label} "Package" ${packageJobName} "host" ${resultFile}

    return
}

storeMetricsForTestJob() {
    requiredParameters WORKSPACE LFS_CI_ROOT

    local jobName=${1}
    local buildNumber=${2}

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

    databaseTestResults ${label} ${testSuiteType} ${jobName} "${targetType}" ${resultFile}

    return
}

storeMetricsFromArtifacts() {
    local jobName=$1
    mustHaveValue "${jobName}" "job name"

    local buildNumber=$2
    mustHaveValue "${buildNumber}" "build number"

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    debug "cleanup artifacts from test in .../bld/bld-test-*"
    execute rm -rf ${workspace}/bld/bld-test*
    debug "copy artifacts from ${jobName} ${buildNumber}..."
    copyArtifactsToWorkspace ${jobName} ${buildNumber} "test" 

    [[ -d ${workspace}/bld/bld-test-artifacts/         ]] || return
    [[ -d ${workspace}/bld/bld-test-artifacts/results/ ]] || return

    for file in ${workspace}/bld/bld-test-artifacts/results/*-metrics-database-values.txt ; do
        [[ -e ${file} ]] || continue
        debug "adding values from ${file} to metrics database"

        local testSuiteType=$(basename ${file} | sed "s/-metrics-database-values.txt//g" )
        mustHaveValue "${testSuiteType}" "testSuiteType"

        export jobName
        local targetType=$(getConfig LFS_CI_uc_test_target_type_mapping)
        mustHaveValue "${targetType}" "target type"

        databaseTestResults ${label} ${testSuiteType} ${jobName} "${targetType}" ${file}

    done

    return
}
