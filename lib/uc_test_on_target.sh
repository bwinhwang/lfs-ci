ci_job_test_on_target() {

    requiredParameters JOB_NAME 

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    info "create workspace for testing"
    cd ${workspace}
    execute build setup
    execute build adddir src-test

    cd ${workspace}/src-test/src/unittest/tests/common/checkuname
    info "installing software on the target"
    info make install

    info "powercycle target"
    execute make powercycle
    info "wait for prompt"
    execute make waitprompt
    info "executing checks"
    execute make test

    return 0
}
