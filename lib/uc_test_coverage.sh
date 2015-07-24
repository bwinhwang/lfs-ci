#!/bin/bash

source ${LFS_CI_ROOT}/lib/artifacts.sh
source ${LFS_CI_ROOT}/lib/createWorkspace.sh
source ${LFS_CI_ROOT}/lib/fingerprint.sh
source ${LFS_CI_ROOT}/lib/makingtest.sh

usecase_LFS_TEST_COVERAGE_COLLECT() {

    local branchName=$(getBranchName)
    mustHaveBranchName

    createBasicWorkspace -l ${branchName} src-test

    mustHavePreparedWorkspace
    _copyCodecoverageArtifactsToWorkspace
    makingTest_testsWithoutTarget

    # copy results to userContent?

    return

}

_copyCodecoverageArtifactsToWorkspace() {
    local fingerPrint=$(getFingerprintOfCurrentJob)
    local dataFile=$(createTempFile)
    local xmlFile=$(createTempFile)

    _getProjectDataFromFingerprint ${fingerPrint} ${xmlFile}
    execute -n ${LFS_CI_ROOT}/bin/getFingerprintData ${xmlFile} > ${dataFile}

    rawDebug ${dataFile}
    rawDebug ${xmlFile}

    for jobData in $(grep CodeCoverage ${dataFile}) ; do
        local jobName=$(cut -d: -f1 <<< ${jobData})
        mustHaveValue "${jobName}" "job name"
        local buildNumber=$(cut -d: -f2 <<< ${jobData})
        mustHaveValue "${buildNumber}" "build number"

        debug "getting test run artifacts for coverage of ${jobName} / ${buildNumber}"

        # no local here
        export LFS_CI_artifacts_can_overwrite_artifacts_from_other_project=1
        copyAndExtractBuildArtifactsFromProject ${jobName} ${buildNumber} "test"
        unset LFS_CI_artifacts_can_overwrite_artifacts_from_other_project
    done


    return
}
