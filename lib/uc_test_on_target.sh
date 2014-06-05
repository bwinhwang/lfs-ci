#!/bin/bash

ci_job_test_on_target() {

    requiredParameters JOB_NAME 

    local workspace=$(getWorkspaceName)
    mustHaveCleanWorkspace
    mustHaveWorkspaceName
    mustHaveWritableWorkspace

    local targetName=$(sed "s/^Test-//" <<< ${JOB_NAME})
    mustHaveValue ${targetName} "target name"
    info "testing on target ${targetName}"

    # find the related jobs of the build
    runOnMaster ${LFS_CI_ROOT}/bin/getUpStreamProject \
                    -j ${TESTED_BUILD_JOBNAME}        \
                    -b ${TESTED_BUILD_NUMBER}         \
                    -h ${serverPath} > ${upstreamsFile}

    local packageJobName=$(    grep Package ${upstreamsFile} | cut -d: -f1)
    local packageBuildNumber=$(grep Package ${upstreamsFile} | cut -d: -f2)
    local buildJobName=$(      grep Build   ${upstreamsFile} | cut -d: -f1)
    local buildBuildNumber=$(  grep Build   ${upstreamsFile} | cut -d: -f2)
    mustHaveValue ${packageJobName}
    mustHaveValue ${packageBuildNumber}
    mustHaveValue ${buildJobName}
    mustHaveValue ${buildBuildNumber}

    trace "output of getUpStreamProject" 
    rawDebug ${upstreamsFile}

    copyArtifactsToWorkspace "${buildJobName}" "${buildBuildNumber}"

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
    sleep 60

    info "executing checks"
    execute make test

    return 0
}

