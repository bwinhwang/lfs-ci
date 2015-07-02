#!/bin/bash

source test/common.sh

oneTimeSetUp() {
    return
}

setUp() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build

    export LFS_CI_CONFIG_FILE=$(createTempFile)
    echo 'LFS_CI_global_mapping_location < job_location:trunk > = pronb-developer'  > ${LFS_CI_CONFIG_FILE}
    echo 'LFS_CI_global_mapping_location <                    > = ${job_location}' >> ${LFS_CI_CONFIG_FILE}

    return
}

tearDown() {
    unset LFS_CI_GLOBAL_BRANCH_NAME
    export LFS_CI_GLOBAL_BRANCH_NAME
    return
}

test1() {
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "pronb-developer" "${value}"
    return
}
test2() {
    assertTrue "getLocationName LFS_CI_-_trunk_-_Build"
    local value=$(getLocationName LFS_CI_-_trunk_-_Build)
    assertEquals "pronb-developer" "${value}"
    return
}
test3() {
    assertTrue "getLocationName LFS_CI_-_FB1506_-_Build"
    local value=$(getLocationName LFS_CI_-_FB1506_-_Build)
    assertEquals "FB1506" "${value}"
    return
}
test4() {
    export JOB_NAME=LFS_CI_-_FB1506_-_Build
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "FB1506" "${value}"
    return
}
test5() {
    export LFS_CI_GLOBAL_BRANCH_NAME="abc"
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "abc" "${value}"
    return
}

source lib/shunit2

exit 0
