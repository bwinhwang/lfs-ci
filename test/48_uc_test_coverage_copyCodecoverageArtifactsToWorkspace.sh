#!/bin/bash

source test/common.sh
source lib/uc_test_coverage.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    getFingerprintOfCurrentJob() {
        mockedCommand "getFingerprintOfCurrentJob $@"
        echo "fingerPrint"
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    getBranchName() {
        echo branchName
    }
    _getProjectDataFromFingerprint() {
        mockedCommand "_getProjectDataFromFingerprint $@"
    }
    execute() {
        mockedCommand "execute $@"
        echo "abc_CodeCoverage_abc:2"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace $@"
        mkdir -p ${WORKSPACE}/workspace
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_copyCodecoverageArtifactsToWorkspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
getFingerprintOfCurrentJob 
_getProjectDataFromFingerprint fingerPrint ${WORKSPACE}/workspace/data.xml
execute -n ${LFS_CI_ROOT}/bin/getFingerprintData ${WORKSPACE}/workspace/data.xml
copyAndExtractBuildArtifactsFromProject abc_CodeCoverage_abc 2 test
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
