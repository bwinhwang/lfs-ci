#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts}  ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_makingtest} ]] && source ${LFS_CI_ROOT}/lib/makingtest.sh

## @fn      ci_job_test_on_target()
#  @brief   usecase test on target
#  @details runs some kind of tests on the targets via making test or fmon
#  @param   <none>
#  @return  <none>
ci_job_test_on_target() {
    requiredParameters JOB_NAME BUILD_NUMBER DELIVERY_DIRECTORY UPSTREAM_PROJECT
    local label=$(basename ${DELIVERY_DIRECTORY})

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

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
            ;;
            testWithoutTarget) makingTest_testsWithoutTarget ;;
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
    local jobName=$(sed "s/_archiveLogs$//" <<< ${JOB_NAME})
    # set the correct jobName
    export JOB_NAME=${jobName}
    
    execute rsync -LavrPe ssh \
        moritz:/lvol2/production_jenkins/jenkins-home/jobs/${jobName}/workspace/. \
        ${workspace}/.
    execute rsync -LavrPe ssh \
        moritz:/lvol2/production_jenkins/test-repos/src-fsmtest/${LABEL}-${jobName}/.  \
        ${workspace}/.

    copyFileToArtifactDirectory ${workspace}/. 
    local artifactsPathOnShare=$(getConfig artifactesShare)/${jobName}/${BUILD_NUMBER}
    linkFileToArtifactsDirectory ${artifactsPathOnShare}/save
    
}
