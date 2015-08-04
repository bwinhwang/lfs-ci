#!/bin/bash

source test/common.sh

source lib/uc_developer_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        echo location > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/location
    }
    specialBuildisRequiredForLrc() {
        mockedCommand "specialBuildisRequiredForLrc $@"
        return ${UT_IS_LRC_BUILD}
    }
    specialBuildCreateWorkspaceAndBuild() {
        mockedCommand "specialBuildCreateWorkspaceAndBuild $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_DEV_-_DEVELOPER_-_Build
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_DEV_-_DEVELOPER_-_Build_-_FSM-r3_-_fsm3_octeon2
    

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_IS_LRC_BUILD=0

    assertTrue "usecase_LFS_DEVELOPER_BUILD_PLATFORM"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
specialBuildCreateWorkspaceAndBuild DEV
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_IS_LRC_BUILD=1

    assertTrue "usecase_LFS_DEVELOPER_BUILD_PLATFORM"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
specialBuildCreateWorkspaceAndBuild DEV
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
