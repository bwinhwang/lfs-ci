#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/config.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }

}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
}
tearDown() {
    true 
}

testGetLocationName_test1() {
    assertEquals "$(getLocationName LFS_CI_-_FB1501_-_Build_-_foobar)"    "FB1501"
    assertEquals "$(getLocationName LFS_CI_-_trunk_-_Build_-_foobar)"     "pronb-developer"
    assertEquals "$(getLocationName LFS_CI_-_fsmr4_-_Build_-_foobar)"     "FSM_R4_DEV"
    assertEquals "$(getLocationName LFS_CI_-_kernel3x_-_Build_-_foobar)"  "KERNEL_3.x_DEV"

    return
}

testGetLocationName_test2() {
    export LFS_CI_GLOBAL_BRANCH_NAME=KNIFE
    assertEquals "$(getLocationName LFS_CI_-_FB1501_-_Build_-_foobar)"    "KNIFE"

    return
}

source lib/shunit2

exit 0

