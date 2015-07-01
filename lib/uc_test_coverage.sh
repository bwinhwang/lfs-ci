#!/bin/bash

usecase_LFS_TEST_COVERAGE_COLLECT() {

    local branchName=$(getBranchName)
    mustHaveBranchName

    createWorkspace -l ${branchName} src-test

    mustHavePreparedWorkspace
    _copyCodecoverageArtifactsToWorkspace
    makingTest_testsWithoutTarget

    # copy results to userContent?

    return

}

_copyCodecoverageArtifactsToWorkspace() {
    local fingerPrint=$(getFingerprintOfCurrentJob)
    local file=$(createTempFile)

    _getProjectDataFromFingerprint ${fingerPrint} ${file}

    for jobData in $(grep CodeCoverage ${file}) ; do
        local jobName=$(cut -d: -f1 <<< ${jobData})
        mustHaveValue "${jobName}" "job name"
        local buildNumber=$(cut -d: -f2 <<< ${jobData})
        mustHaveValue "${buildNumber}" "build number"

        debug "getting test run artifacts for coverage of ${jobName} / ${buildNumber}"

        # no local here
        LFS_CI_artifacts_can_overwrite_artifacts_from_other_project=1
        copyAndExtractBuildArtifactsFromProject ${jobName} ${buildNumber} "test"
        unset LFS_CI_artifacts_can_overwrite_artifacts_from_other_project
    done


    return
}
