#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_jenkins}   ]] && source ${LFS_CI_ROOT}/lib/makingtest.sh

## @fn      ci_job_test_on_target()
#  @brief   usecase test on target
#  @details runs some kind of tests on the targets via making test or fmon
#  @param   <none>
#  @return  <none>
ci_job_test_on_target() {
    requiredParameters JOB_NAME BUILD_NUMBER LABEL DELIVERY_DIRECTORY UPSTREAM_PROJECT

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

    for type in $(getConfig LFS_CI_uc_test_making_test_type) ; do
        info "running test type ${type} on target ${testTargetName}"
        case ${testType} in
            checkUname)        makingTest_checkUname ;;
            testProductionLRC) makingTest_testLRC ;;
            testProductionFSM) 
                               makingTest_testFSM
                               fmon_tests 
            ;;
            *) fatal "unknown testType"; ;;
        esac
    done

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

uc_job_test_on_target_archive_logs() {

    requiredParameters JOB_NAME BUILD_NUMBER LABEL
    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace

    
    execute rsync -LavrPe ssh \
        moritz:/lvol2/production_jenkins/jenkins-home/jobs/${JOB_NAME}/workspace/. \
        ${workspace}/.
    execute rsync -LavrPe ssh \
        moritz:/lvol2/production_jenkins/test-repos/src-fsmtest/${LABEL}-${JOB_NAME}/. 
        ${workspace}/.

    copyFileToArtifactDirectory ${workspace}/. 
    local artifactsPathOnShare=$(getConfig artifactesShare)/${JOB_NAME}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}
    
}
