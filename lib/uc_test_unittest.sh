#!/bin/bash
## @file    uc_test_unittest_ddal.sh
#  @brief   the unittest ddal usecase
#  @details job name: LFS_CI_-_trunk_-_Unittest_-_FSM-r3_-_fsm3_octeon2_-_ddal

[[ -z ${LFS_CI_SOURCE_common}          ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh
[[ -z ${LFS_CI_SOURCE_database}        ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ci_job_test_unittest()
#  @brief   create a workspace and run the unit tests for ddal
#  @todo    lot of pathes are hardcoded at the moment. make this more configureable
#  @param   <none>
#  @return  <none>
ci_job_test_unittest() {

    requiredParameters UPSTREAM_PROJECT UPSTREAM_BUILD JOB_NAME BUILD_NUMBER WORKSPACE

    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName

    createOrUpdateWorkspace --allowUpdate

    mustHaveNextCiLabelName
    local label=$(getNextCiLabelName)
    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${label}

    local revision=$(latestRevisionFromRevisionStateFile)
    mustHaveValue "${revision}" "revision"

    checkoutSubprojectDirectories src-unittests ${revision}

    case "$JOB_NAME"
    in *FSM-r4*) target_type=FSM-r4
    ;; *)        target_type=FSM-r3
    esac

    case "$JOB_NAME"
    in *ddg) subsys=drivers
    ;; *)        subsys=ddal
    esac

    case "$JOB_NAME"
    in *fsmddg)  src_type=fsmddg
    ;; *ddg)     src_type=ddg
    ;; *fsmddal) src_type=fsmddal
    ;; *)        src_type=unknown
    esac
    execute cd ${workspace}/src-unittests/src/testsuites/continuousintegration/unittest

    info "creating testconfig"
    execute make testconfig-overwrite TESTBUILD=${workspace} TESTTARGET=localhost-x86

    info "running test suite.."
    execute make clean
    execute -i make -i test-xmloutput JOB_NAME="$JOB_NAME" TARGET_TYPE="${target_type}" SUBSYS="${subsys}" SRC_TYPE="${src_type}"

    execute rm -rf ${workspace}/xml-reports 
    execute mkdir -p ${workspace}/xml-reports 
    execute cp -rf xml-reports/* ${workspace}/xml-reports || true

    execute rm -rf ${workspace}/html 
    execute mkdir -p ${workspace}/html 
    execute cp -rf __artifacts/html/* ${workspace}/html || true

#   TODO: add results to DB

    return
}
