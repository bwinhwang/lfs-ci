#!/bin/bash

source test/common.sh
source lib/uc_test_coverage.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
    }
    mustHaveNextLabelName() {
        mockedCommand "mustHaveNextLabelName $@"
    }
    getNextReleaseLabel() {
        mockedCommand "getNextReleaseLabel $@"
        echo LABEL
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Build
    export UPSTREAM_BUILD=1234
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2
    export BUILD_NUMBER=1234
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "mustHavePreparedWorkspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
getConfig LFS_CI_prepare_workspace_required_artifacts
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 LFS_CI_prepare_workspace_required_artifacts
mustHaveNextLabelName 
getNextReleaseLabel 
setBuildDescription LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2 1234 LABEL
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    assertTrue "mustHavePreparedWorkspace -C"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_prepare_workspace_required_artifacts
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 LFS_CI_prepare_workspace_required_artifacts
mustHaveNextLabelName 
getNextReleaseLabel 
setBuildDescription LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2 1234 LABEL
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    assertTrue "mustHavePreparedWorkspace -C -B"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}

    return
}
test3_long() {
    assertTrue "mustHavePreparedWorkspace --no-build-description --no-clean-workspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}

    return
}

test4() {
    assertTrue "mustHavePreparedWorkspace BUILD 12345"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
getConfig LFS_CI_prepare_workspace_required_artifacts
copyAndExtractBuildArtifactsFromProject BUILD 12345 LFS_CI_prepare_workspace_required_artifacts
mustHaveNextLabelName 
getNextReleaseLabel 
setBuildDescription LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2 1234 LABEL
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
