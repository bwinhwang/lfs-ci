#!/bin/bash

source lib/common.sh
initTempDirectory

oneTimeSetUp() {
    return
}

setUp() {
    return
}

tearDown() {
    return
}

testAdminJobNames() {
    local JOB_NAME=Admin_-_cleanup_-_ulm
    assertEquals "Admin"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} productName)"
    assertEquals "cleanup"  "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} taskName)"
    assertEquals "ulm"      "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} subTaskName)"

    local JOB_NAME=Admin_-_cleanup
    assertEquals "Admin"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} productName)"
    assertEquals "cleanup"  "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} taskName)"
    assertEquals ""         "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} subTaskName)"
}
testBuildJobName_Branch() {
    local JOB_NAME=LFS_CI_-_LRC_ABA_-_Build_-_FSM-r4_-_fsm4_axm
    assertEquals "LRC_ABA"  "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} location)"
    assertEquals "FSM-r4"   "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} subTaskName)"
    assertEquals "Build"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} taskName)"
    assertEquals "fsm4_axm" "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} platform)"
    assertEquals "LFS"      "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} productName)"
}
testBuildJobName() {
    local JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    assertEquals "trunk"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} location)"
    assertEquals "FSM-r4"   "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} subTaskName)"
    assertEquals "Build"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} taskName)"
    assertEquals "fsm4_axm" "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} platform)"
    assertEquals "LFS"      "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} productName)"
}
testBuildSummaryJobName() {
    local JOB_NAME=LFS_CI_-_trunk_-_Build
    assertEquals "trunk"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} location)"
    assertEquals ""         "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} subTaskName)"
    assertEquals "Build"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} taskName)"
    assertEquals ""         "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} platform)"
    assertEquals "LFS"      "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} productName)"
}
testTestSummaryJobName() {
    local JOB_NAME=LFS_CI_-_trunk_-_Test
    assertEquals "trunk"    "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} location)"
    assertEquals ""         "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} subTaskName)"
    assertEquals "Test"     "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} taskName)"
    assertEquals ""         "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} platform)"
    assertEquals "LFS"      "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} productName)"
}
testJobNameWithLongStyle() {
    local JOB_NAME=LFS_CI_-_trunk_-_KlocworkBuild_-_FSM-r4_-_fsm4_axm_-_DDAL
    assertEquals "LFS"           "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} productName)"
    assertEquals "trunk"         "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} location)"
    assertEquals "FSM-r4"        "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} subTaskName)"
    assertEquals "KlocworkBuild" "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} taskName)"
    assertEquals "fsm4_axm"      "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} platform)"
    assertEquals "DDAL"          "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 5)"
}
testJobNameWithNumbers() {
    local JOB_NAME=LFS_CI_-_trunk_-_KlocworkBuild_-_FSM-r4_-_fsm4_axm_-_DDAL
    assertEquals "LFS"           "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 0)"
    assertEquals "trunk"         "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 1)"
    assertEquals "KlocworkBuild" "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 2)"
    assertEquals "FSM-r4"        "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 3)"
    assertEquals "fsm4_axm"      "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 4)"
    assertEquals "DDAL"          "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 5)"
}
testJobNameAdminJobs_2() {
    local JOB_NAME=Admin_-_cleanUp
    assertEquals "Admin"     "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 0)"
    assertEquals "cleanUp"   "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 1)"
    assertEquals ""          "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 2)"
    assertEquals ""          "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 3)"
    assertEquals ""          "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 4)"
    assertEquals ""          "$(${LFS_CI_ROOT}/bin/getFromString.pl ${JOB_NAME} 5)"
}

source lib/shunit2

exit 0
