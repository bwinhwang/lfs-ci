#!/bin/bash

[[ -z ${LFS_CI_SOURCE_artifacts} ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_jenkins} ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh

ci_job_test_on_target() {
    requiredParameters JOB_NAME BUILD_NUMBER LABEL DELIVERY_DIRECTORY

    setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} ${LABEL}

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    info "create workspace for testing"
    cd ${workspace}
    execute build setup
    execute build adddir src-test

    # Note: TESTTARGET lowercase with ,,
    local make="make TESTTARGET=${targetName,,}"    

    cd ${workspace}/src-test/src/unittest/tests/common/checkuname
    info "installing software on the target"
    execute ${make} install WORKSPACE=${DELIVERY_DIRECTORY} 

    info "powercycle target"
    execute ${make} powercycle

    info "wait for prompt"
    execute ${make} waitprompt
    sleep 60

    info "executing checks"
    execute ${make} test

    info "show uptime"
    execute ${make} invoke_console_cmd CMD=uptime

    info "show kernel version"
    ${make} invoke_console_cmd CMD="uname -a"

    info "testing done."

    return 0
}

