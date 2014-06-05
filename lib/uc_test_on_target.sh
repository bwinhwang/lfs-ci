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

    info "installing software on the target"
    info "powercycle target"
    info "executing checks"

    return 0
}
