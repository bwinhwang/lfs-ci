#!/bin/bash
## @file  uc_test_on_target.sh
#  @brief the test on target usecase

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins}         ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_makingtest}      ]] && source ${LFS_CI_ROOT}/lib/makingtest.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_booking}         ]] && source ${LFS_CI_ROOT}/lib/booking.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh

## @fn      usecase_LFS_CI_TESTING_TMF_ON_TARGET()
#  @brief   runs the usecase LFS_CI_TESTING_TMF_ON_TARGET (wrapper only)
#  @param   <none>
#  @return  <none>
usecase_LFS_CI_TESTING_TMF_ON_TARGET() {
    ci_job_test_on_target
}

## @fn      ci_job_test_on_target()
#  @brief   usecase test on target
#  @details runs some kind of tests on the targets via making test or fmon
#  @param   <none>
#  @return  <none>
ci_job_test_on_target() {
    requiredParameters LABEL JOB_NAME BUILD_NUMBER DELIVERY_DIRECTORY UPSTREAM_PROJECT

    mustHavePreparedWorkspace

    info "testing production ${LABEL}"
    eventSubTestStarted 
    exit_add _exitHandlerDatabaseEventsSubTestFailed

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    local locationName=$(getLocationName ${UPSTREAM_PROJECT})
    mustHaveValue "${locationName}" "location name from ${UPSTREAM_PROJECT}"

    if [[ ${JOB_NAME} =~ ^Test- ]] ; then
        # legacy: using the Test-<targetName> job. No detailed information about
        # the workspace is available at the moment.
        # TODO: demx2fk3 2015-02-13 we are using the wrong revision to checkout src-test
        info "create workspace for testing on ${locationName}"
        createBasicWorkspace -l ${locationName} src-test
    else
        local requireCompleteWorkspace=$(getConfig LFS_CI_uc_test_require_complete_workspace)
        if [[ ${requireCompleteWorkspace} ]] ; then
            copyFileFromBuildDirectoryToWorkspace ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fingerprint.txt
            mv ${WORKSPACE}/fingerprint.txt ${WORKSPACE}/revisions.txt
            createWorkspace
        else
            # TODO: demx2fk3 2015-02-13 we are using the wrong revision to checkout src-test
            createBasicWorkspace -l ${locationName} src-test
        fi
    fi

    local requiredArtifacts=$(getConfig LFS_CI_UC_test_required_artifacts)
    copyAndExtractBuildArtifactsFromProject "${UPSTREAM_PROJECT}" "${UPSTREAM_BUILD}" "${requiredArtifacts}"

    mustHaveReservedTarget
    local targetName=$(_reserveTarget)
    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${LABEL}<br>${targetName}"

    # for legacy: If job name is Test-<targetName> we don't know the type of the target
    local testType=$(getConfig LFS_CI_uc_test_making_test_type -t "testTargetName:${targetName}")
    mustHaveValue "${testType}" "test type"


    for type in ${testType} ; do
        info "running test type ${type} on target ${targetName}"
        case ${testType} in
            checkUname)        makingTest_checkUname         ;;
            testProductionLRC) makingTest_testLRC            ;;
            testProductionFSM) makingTest_testFSM            ;;
            testWithoutTarget) makingTest_testsWithoutTarget ;;
            testSandboxDummy)  testSandboxDummy              ;;
            *)                 fatal "unknown testType";     ;;
        esac
    done

    eventSubTestFinished
    info "testing done."
    return
}
## @fn      _exitHandlerDatabaseEventsSubTestFailed()
#  @brief   exit handler for a sub test job to store the event into the database
#  @param   {rc}    exit code
#  @return  <none>
_exitHandlerDatabaseEventsSubTestFailed() {
    [[ ${1} -gt 0 ]] && eventSubTestFailed 
    return
}

## @fn      uc_job_test_on_target_archive_logs()
#  @brief   copy the results / logs / artifacts from the test job to the archive share (aka /build share)
#  @param   <none>
#  @return  <none>
uc_job_test_on_target_archive_logs() {

    requiredParameters JOB_NAME BUILD_NUMBER LABEL
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    local jobName=$(sed "s/_archiveLogs$//" <<< ${JOB_NAME})
    # set the correct jobName
    export JOB_NAME=${jobName}

    local branchName=$(getBranchName ${UPSTREAM_PROJECT})
    mustHaveValue "${branchName}" "branch name from ${UPSTREAM_PROJECT}"

    local testReposPathOnMoritz=$(getConfig LFS_CI_uc_test_on_target_test_repos_on_moritz -t location:${branchName})
    mustHaveValue "${testReposPathOnMoritz}" "test-repos path on moritz"
    
    execute -r 10 rsync -LavrPe ssh \
        moritz:/lvol2/production_jenkins/jenkins-home/jobs/${jobName}/workspace/. \
        ${workspace}/.
    execute -r 10 rsync -LavrPe ssh \
        moritz:${testReposPathOnMoritz}/src-fsmtest/${LABEL}-${jobName}/.  \
        ${workspace}/.

    copyFileToArtifactDirectory ${workspace}/. 
    # TODO: demx2fk3 2015-01-23 make this in a function
    local artifactsPathOnShare=$(getConfig artifactesShare)/${jobName}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}/save

    return
}

## @fn      usecase_LFS_CI_SANDBOX_TEST_TARGET_DUMMY()
#  @brief   only a dummy function for testing
#  @details dummy function that only add entries to db
#  @param   <none>
#  @return  <none>
testSandboxDummy() {
    requiredParameters LFS_CI_ROOT

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    local file=$(getConfig LFS_CI_uc_test_dummy_sandbox_result_xml_file)
    execute mkdir -p ${workspace}/xml-reports/                                                                                                   
    execute cp ${file} ${workspace}/xml-reports/

    return 0
}
