#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh

ci_job_test_on_target() {
    requiredParameters JOB_NAME 

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local upstreamJobName=${UPSTREAM_PROJECT}
    local upstreamBuildNumber=${UPSTREAM_BUILD}

    local testWorkspace=$(getWorkspaceDirectoryOfBuild ${upstreamJobName})

    info "create workspace for testing"
    cd ${workspace}
    execute build setup
    execute build adddir src-test

    cd ${workspace}/src-test/src/unittest/tests/common/checkuname
    info "installing software on the target"
    make install WORKSPACE=${testWorkspace}

    info "powercycle target"
    execute make powercycle
    info "wait for prompt"
    execute make waitprompt
    sleep 60

    info "executing checks"
    execute make test

    info "show uptime"
    execute make invoke_console_cmd CMD=uptime

    info "testing done."

    return 0
}

