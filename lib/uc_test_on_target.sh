#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_makingtest} ]] && source ${LFS_CI_ROOT}/lib/makingtest.sh
[[ -z ${LFS_CI_SOURCE_database}   ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_test_on_target()
#  @brief   usecase test on target
#  @details runs some kind of tests on the targets via making test or fmon
#  @param   <none>
#  @return  <none>
ci_job_test_on_target() {
    requiredParameters LABEL JOB_NAME BUILD_NUMBER DELIVERY_DIRECTORY UPSTREAM_PROJECT

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${LABEL}

    local targetName=$(reserveTarget)
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local branchName=$(getLocationName ${UPSTREAM_PROJECT})
    mustHaveValue "${branchName}" "branch name"

    info "create workspace for testing on ${branchName}"
    createBasicWorkspace -l ${branchName} src-test

    export testTargetName=${targetName}
    local testType=$(getConfig LFS_CI_uc_test_making_test_type)

    databaseEventTestStarted ${LABEL} ${testTargetName}

    for type in $(getConfig LFS_CI_uc_test_making_test_type) ; do
        info "running test type ${type} on target ${testTargetName}"
        case ${testType} in
            checkUname)        makingTest_checkUname ;;
            testProductionLRC) makingTest_testLRC ;;
            testProductionFSM) makingTest_testFSM ;;
            testWithoutTarget) makingTest_testsWithoutTarget ;;
            *)                 fatal "unknown testType"; ;;
        esac
    done

    databaseEventTestFinished ${LABEL} ${testTargetName}

#     addTestResultsToMetricDatabase ${workspace}/TODO.xml \
#                                    ${LABEL}              \
#                                    "TMF_${testType}"     \
#                                    "${testTargetName}"   \
#                                    "FSMr-x"
    info "testing done."
    return
}



## @fn      reserveTarget
#  @brief   make a reserveration from TAToo to get a target
#  @param   <none>
#  @return  name of the target
reserveTarget() {

    requiredParameters JOB_NAME

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    echo ${targetName}
   
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
    
    execute rsync -LavrPe ssh \
        moritz:/lvol2/production_jenkins/jenkins-home/jobs/${jobName}/workspace/. \
        ${workspace}/.
    execute rsync -LavrPe ssh \
        moritz:/lvol2/production_jenkins/test-repos/src-fsmtest/${LABEL}-${jobName}/.  \
        ${workspace}/.

    # store results in metric database
    info "storing result numbers in metric database"
    local resultFile=$(createTempFile)
    local test_total=$(grep '<testcase ' ${workspace}/ftcm_junit.xml | wc -l)
    local test_failed=$(grep '<failure>' ${workspace}/ftcm_junit.xml | wc -l)
    echo "test_failed;${test_failed}" >> ${resultFile}
    echo "test_total;${test_total}"   >> ${resultFile}
    rawDebug ${resultFile}

    databaseTestResults ${LABEL}     \
                        FMON         \
                        ${jobName}   \
                        FSM-r3       \
                        ${resultFile}

    copyFileToArtifactDirectory ${workspace}/. 
    local artifactsPathOnShare=$(getConfig artifactesShare)/${jobName}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}/save

    return
}
