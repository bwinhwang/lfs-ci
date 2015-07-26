#!/bin/bash

source test/common.sh

source lib/customSCM.common.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
}
oneTimeTearDown() {
    true
}
setUp() {
    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/file.cfg
    export JOB_NAME=LFS_CI_-_FB1507_-_ABC
    true
}
tearDown() {
    true
}

test1() {
    local value=$(getUpstreamProjectName LFS_CI_-_FB1507_-_Test)
    assertEquals "LFS_CI_-_FB1507_-_SmokeTest" "${value}"
    return
}
test2() {
    export JOB_NAME=LFS_CI_-_FB1507_-_Test
    local value=$(getUpstreamProjectName)
    assertEquals "LFS_CI_-_FB1507_-_SmokeTest" "${value}"
    return
}
test3() {
    local value=$(getUpstreamProjectName LFS_CI_-_trunk_-_Test)
    assertEquals "LFS_CI_-_trunk_-_SmokeTest" "${value}"
    return
}
test4() {
    export JOB_NAME=LFS_CI_-_trunk_-_Test
    local value=$(getUpstreamProjectName)
    assertEquals "LFS_CI_-_trunk_-_SmokeTest" "${value}"
    return
}

source lib/shunit2

exit 0

