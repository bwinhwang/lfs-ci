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
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    getBranchName() {
        echo branchName
    }
    createBasicWorkspace() {
        mockedCommand "createBasicWorkspace $@"
    }
    _copyCodecoverageArtifactsToWorkspace() {
        mockedCommand "_copyCodecoverageArtifactsToWorkspace $@"
    }
    makingTest_testsWithoutTarget() {
        mockedCommand "makingTest_testsWithoutTarget $@"
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
    }
    mustHaveNextCiLabelName() {
        mockedCommand "mustHaveNextCiLabelName $@"
    }
    getNextCiLabelName() {
        echo PS_LFS_OS_2015_09_0001
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # assertTrue "usecase_LFS_TEST_COVERAGE_COLLECT"
    usecase_LFS_TEST_COVERAGE_COLLECT

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName 
getConfig LFS_CI_UC_package_copy_to_share_real_location
createBasicWorkspace -l branchName src-test src-fsmddal
mustHavePreparedWorkspace --no-clean-workspace
_copyCodecoverageArtifactsToWorkspace 
makingTest_testsWithoutTarget 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
