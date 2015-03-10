#!/bin/bash
## @file  uc_test_on_target.sh
#  @brief the test on target usecase

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_makingtest} ]] && source ${LFS_CI_ROOT}/lib/makingtest.sh
[[ -z ${LFS_CI_SOURCE_database}   ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_booking}    ]] && source ${LFS_CI_ROOT}/lib/booking.sh

## @fn      ci_job_test_on_target()
#  @brief   usecase test on target
#  @details runs some kind of tests on the targets via making test or fmon
#  @param   <none>
#  @return  <none>
ci_job_test_on_target() {
    requiredParameters LABEL JOB_NAME BUILD_NUMBER DELIVERY_DIRECTORY UPSTREAM_PROJECT

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${LABEL}

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    local branchName=$(getLocationName ${UPSTREAM_PROJECT})
    mustHaveValue "${branchName}" "branch name"

    # TODO: demx2fk3 2015-02-13 we are using the wrong revision to checkout src-test
    info "create workspace for testing on ${branchName}"
    createBasicWorkspace -l ${branchName} src-test

    copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} "fsmci"

    mustHaveReservedTarget
    local targetName=$(_reserveTarget)

    local testType=$(getConfig LFS_CI_uc_test_making_test_type -t testTargetName:${targetName})
    mustHaveValue "${testType}" "test type"

    databaseEventSubTestStarted 
    exit_add _exitHandlerDatabaseEventsSubTestFailed

    for type in $(getConfig LFS_CI_uc_test_making_test_type) ; do
        info "running test type ${type} on target ${targetName}"
        case ${testType} in
            checkUname)        makingTest_checkUname ;;
            testProductionLRC) makingTest_testLRC ;;
            testProductionFSM) makingTest_testFSM ;;
            testWithoutTarget) makingTest_testsWithoutTarget ;;
            *)                 fatal "unknown testType"; ;;
        esac
    done

    info "testing done."
    return
}

_exitHandlerDatabaseEventsSubTestFailed() {
    [[ ${1} -gt 0 ]] && databaseEventSubTestFailed 
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

    local testReposPathOnMoritz=$(getConfig LFS_CI_uc_test_on_target_test_repos_on_moritz)
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
