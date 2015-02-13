#!/bin/bash
## @file  uc_test
#  @brief the test usecase

[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_database}  ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_test()
#  @brief   dispatcher for test jobs
#  @details prepare the build artifacts to have it in the correct way for the test framework
#  @param   <none>
#  @return  <none>
ci_job_test() {
    # get the package build job (upstream_project and upstream_build)
    # prepare the workspace directory for all test builds
    # copy the files to a workspace directory
    # jobs will be executed by jenkins job, so we can exit very early
    requiredParameters JOB_NAME BUILD_NUMBER WORKSPACE UPSTREAM_PROJECT UPSTREAM_BUILD

    local upstreamProject=${UPSTREAM_PROJECT}
    local upstreamBuildNumber=${UPSTREAM_BUILD}
    info "upstreamProject data: ${upstreamProject} / ${upstreamBuildNumber}"

    local buildJobName=$(getBuildJobNameFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})
    local buildBuildNumber=$(getBuildBuildNumberFromUpstreamProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD})

    local requiredArtifacts=$(getConfig LFS_CI_UC_test_required_artifacts)
    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}" "${requiredArtifacts}"

    # structure of jobs
    # Test
    #  |--- FSM-r2 summary
    #  |     \---- Test-fsmr2_target1
    #  |--- FSM-r3 summary
    #  |     |---- Test-fsmr3_target1
    #  |     |---- Test-fsmr3_target2
    #  |     \---- Test-fsmr3_target3
    #  \--- FSM-r4 summary
    #        |---- Test-fsmr4_target1
    #        |---- Test-fsmr4_target2
    #        \---- Test-fsmr4_target3
    # if we are the Test job, we have to prepare the upstream data for the downstream jobs          
    if [[ ${JOB_NAME} =~ .*_-_Test$ ]] ; then

        debug "we are the summary test job"

        local ciBuildShare=$(getConfig LFS_CI_UC_package_internal_link)
        local workspace=${ciBuildShare}/build_${upstreamBuildNumber}
        mustExistSymlink ${workspace}

        local realDirectory=$(readlink ${workspace})
        local labelName=$(basename ${realDirectory})
        mustExistDirectory ${realDirectory}
        mustHaveValue "${labelName}" "label name from ${workspace}"

        info "using build ${labelName} in ${realDirectory}"

        info "creating upstream file in workspace"
        execute rm -rf ${WORKSPACE}/upstream
        echo "upstreamProject=${upstreamProject}"          > ${WORKSPACE}/upstream
        echo "upstreamBuildNumber=${upstreamBuildNumber}" >> ${WORKSPACE}/upstream
        rawDebug ${WORKSPACE}/upstream

        copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${WORKSPACE}/upstream

        execute rm -rf ${WORKSPACE}/properties
        echo "LABEL=${labelName}"                   > ${WORKSPACE}/properties
        echo "DELIVERY_DIRECTORY=${realDirectory}" >> ${WORKSPACE}/properties
        rawDebug ${WORKSPACE}/properties

        copyFileFromWorkspaceToBuildDirectory ${JOB_NAME} ${BUILD_NUMBER} ${WORKSPACE}/properties

    else

        debug "we are the slave test job"

        info "overwrite upstreamProject to ${upstreamProject} ${upstreamBuildNumber}"
        copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} upstream 
        mustExistFile ${WORKSPACE}/upstream
        rawDebug ${WORKSPACE}/upstream

        source ${WORKSPACE}/upstream

        info "overwrite upstreamProject to ${upstreamProject} ${upstreamBuildNumber}"
        copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} properties 
        mustExistFile ${WORKSPACE}/properties
        rawDebug ${WORKSPACE}/properties

        source ${WORKSPACE}/properties

        # for setBuildDescription
        local labelName=${LABEL}
    fi

    info "copy dummy test junit xml file into workspace"
    execute cp ${LFS_CI_ROOT}/etc/junit_dummytest.xml ${WORKSPACE}

    setBuildDescription "${JOB_NAME}" "${BUILD_NUMBER}" "${labelName}"
    return
}


ci_job_test_collect_metrics() {
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

        [[ "${jobName}" =~ _Test$      ]] && continue
        [[ "${jobName}" =~ makingTest$ ]] && continue
        [[ "${jobName}" =~ target$     ]] && continue
        [[ "${jobName}" =~ lcpa$       ]] && continue

        [[ "${state}"   = FAILURE   ]] && continue
        [[ "${state}"   = ABORTED   ]] && continue
        [[ "${state}"   = NOT_BUILT ]] && continue

        storeMetricsForTestJob ${jobName} ${buildNumber}

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
