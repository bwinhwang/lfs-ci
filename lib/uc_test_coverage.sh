#!/bin/bash

# @file uc_test_coverage.sh
# @brief collect code coverage data and create a html report out of it

[[ -z ${LFS_CI_SOURCE_artifacts}       ]] && source ${LFS_CI_ROOT}/lib/artifacts.sh
[[ -z ${LFS_CI_SOURCE_fingerprint}     ]] && source ${LFS_CI_ROOT}/lib/fingerprint.sh
[[ -z ${LFS_CI_SOURCE_makingtest}      ]] && source ${LFS_CI_ROOT}/lib/makingtest.sh
[[ -z ${LFS_CI_SOURCE_createWorkspace} ]] && source ${LFS_CI_ROOT}/lib/createWorkspace.sh


## @fn      usecase_LFS_TEST_COVERAGE_COLLECT()
#  @brief   collect the test coverage data from tests
#  @param   <none>
#  @return  <none>
usecase_LFS_TEST_COVERAGE_COLLECT() {

    local branchName=$(getBranchName)
    mustHaveBranchName

    createBasicWorkspace -l ${branchName} src-test

    mustHavePreparedWorkspace
    _copyCodecoverageArtifactsToWorkspace
    makingTest_testsWithoutTarget

    return
}

## @fn      _copyCodecoverageArtifactsToWorkspace()
#  @brief   copy code coverage artifacts from test jobs into workspace
#  @param   <none>
#  @return  <none>
_copyCodecoverageArtifactsToWorkspace() {
    local workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    local fingerPrint=$(getFingerprintOfCurrentJob)
    mustHaveValue "${fingerPrint}" "fingerprint md5 sum of current job"

    local xmlFile=${workspace}/data.xml
    local dataFile=${workspace}/data.txt

    _getProjectDataFromFingerprint ${fingerPrint} ${xmlFile}
    touch ${dataFile}
    ls -la ${dataFile}
    execute -n ${LFS_CI_ROOT}/bin/getFingerprintData ${xmlFile} > ${dataFile}

    rawDebug ${dataFile}
    rawDebug ${xmlFile}

    for jobData in $(grep CodeCoverage ${dataFile}) ; do
        local jobName=$(cut -d: -f1 <<< ${jobData})
        mustHaveValue "${jobName}" "job name"
        local buildNumber=$(cut -d: -f2 <<< ${jobData})
        mustHaveValue "${buildNumber}" "build number"

        debug "getting test run artifacts for coverage of ${jobName} / ${buildNumber}"

        # must be used in getConfig => export
        export LFS_CI_artifacts_can_overwrite_artifacts_from_other_project=1
        copyAndExtractBuildArtifactsFromProject ${jobName} ${buildNumber} "test"
        unset LFS_CI_artifacts_can_overwrite_artifacts_from_other_project
    done

    return
}
