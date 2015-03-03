#!/bin/bash

source test/common.sh

source lib/special_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
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
    export JOB_NAME=LFS_CI_-_LRC_-_Build_-_LRC_-_lcpa
    assertTrue "specialBuildisRequiredForLrc LRC"
    return
}
test2() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    assertFalse "specialBuildisRequiredForLrc LRC"
    return
}
test3() {
    export JOB_NAME=LFS_CI_-_LRC_-_Build_-_LRC_-_lcpa
    assertFalse "specialBuildisRequiredForLrc trunk"
    return
}
test4() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    assertTrue "specialBuildisRequiredForLrc trunk"
    return
}

source lib/shunit2

exit 0
