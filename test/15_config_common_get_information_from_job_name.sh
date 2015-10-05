#!/bin/bash

source test/common.sh

oneTimeSetUp() {
    return
}

setUp() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2
    export LFS_CI_CONFIG_FILE=$(createTempFile)
    echo 'LFS_CI_global_mapping_location < job_location:trunk > = pronb-developer'  > ${LFS_CI_CONFIG_FILE}
    echo 'LFS_CI_global_mapping_location <                    > = ${job_location}' >> ${LFS_CI_CONFIG_FILE}
    echo 'LFS_CI_global_mapping_branch_location < branchName:trunk > = pronb-developer' >> ${LFS_CI_CONFIG_FILE}
    echo 'LFS_CI_global_mapping_location_branch < locationName:pronb-deveoper > = trunk' >> ${LFS_CI_CONFIG_FILE}
    echo 'LFS_CI_global_mapping_branch_location < branchName:FB1506 > = FB1506' >> ${LFS_CI_CONFIG_FILE}
    echo 'LFS_CI_global_mapping_location_branch < locationName:FB1505 > = FB1506' >> ${LFS_CI_CONFIG_FILE}

    return
}

tearDown() {
    unset LFS_CI_GLOBAL_LOCATION_NAME
    export LFS_CI_GLOBAL_LOCATION_NAME
    return
}

test1_getSubTaskNameFromJobName() {
    assertTrue "getSubTaskNameFromJobName"
    local value=$(getSubTaskNameFromJobName)
    assertEquals "FSM-r3" "${value}"
    return
}
test2_getSubTaskNameFromJobName() {
    assertTrue "getSubTaskNameFromJobName LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm"
    local value=$(getSubTaskNameFromJobName LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm)
    assertEquals "FSM-r4" "${value}"
    return
}

test3_getTargetBoardName() {
    assertTrue "getTargetBoardName"
    local value=$(getTargetBoardName)
    assertEquals "fsm3_octeon2" "${value}"
    return
}
test4_getTargetBoardName() {
    assertTrue "getTargetBoardName LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm"
    local value=$(getTargetBoardName LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm)
    assertEquals "fsm4_axm" "${value}"
    return
}

test5_getProductNameFromJobName_global() {
    export LFS_CI_GLOBAL_PRODUCT_NAME=ABC
    assertTrue "getProductNameFromJobName"
    local value=$(getProductNameFromJobName)
    assertEquals "ABC" "${value}"
    export LFS_CI_GLOBAL_PRODUCT_NAME=
    return
}

test5_getProductNameFromJobName() {
    assertTrue "getProductNameFromJobName"
    local value=$(getProductNameFromJobName)
    assertEquals "LFS" "${value}"
    return
}

test6_getProductNameFromJobName() {
    assertTrue "getProductNameFromJobName UBOOT_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm"
    local value=$(getProductNameFromJobName UBOOT_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm)
    assertEquals "UBOOT" "${value}"
    return
}

test6_getProductNameFromJobName_global() {
    export LFS_CI_GLOBAL_PRODUCT_NAME=ABC
    assertTrue "getProductNameFromJobName UBOOT_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm"
    local value=$(getProductNameFromJobName UBOOT_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm)
    assertEquals "ABC" "${value}"
    export LFS_CI_GLOBAL_PRODUCT_NAME=
    return
}

test7_getTaskNameFromJobName() {
    assertTrue "getTaskNameFromJobName"
    local value=$(getTaskNameFromJobName)
    assertEquals "Build" "${value}"
    return
}
test8_getTaskNameFromJobName() {
    assertTrue "getTaskNameFromJobName LFS_CI_-_trunk_-_Build"
    local value=$(getTaskNameFromJobName LFS_CI_-_trunk_-_Build)
    assertEquals "Build" "${value}"
    return
}

test9_getLocationName() {
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "pronb-developer" "${value}"
    return
}
test10_getLocationName() {
    assertTrue "getLocationName LFS_CI_-_trunk_-_Build"
    local value=$(getLocationName LFS_CI_-_trunk_-_Build)
    assertEquals "pronb-developer" "${value}"
    return
}
test11_getLocationName() {
    assertTrue "getLocationName LFS_CI_-_FB1506_-_Build"
    local value=$(getLocationName LFS_CI_-_FB1506_-_Build)
    assertEquals "FB1506" "${value}"
    return
}
test12_getLocationName() {
    export JOB_NAME=LFS_CI_-_FB1506_-_Build
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "FB1506" "${value}"
    return
}
test13_getLocationName() {
    export LFS_CI_GLOBAL_LOCATION_NAME="abc"
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "abc" "${value}"
    return
}
test14_getLocationName() {
    unset JOB_NAME
    export JOB_NAME
    assertTrue "test14_getLocationName" "getLocationName"
    return
}


test15_getBranchName() {
    assertTrue "test15_getBranchName" "getLocationName"
    local value=$(getLocationName)
    assertEquals "pronb-developer" "${value}"
    return
}
test16_getBranchName() {
    assertTrue "getLocationName LFS_CI_-_trunk_-_Build"
    local value=$(getLocationName LFS_CI_-_trunk_-_Build)
    assertEquals "pronb-developer" "${value}"
    return
}
test17_getBranchName() {
    assertTrue "getLocationName LFS_CI_-_FB1506_-_Build"
    local value=$(getLocationName LFS_CI_-_FB1506_-_Build)
    assertEquals "FB1506" "${value}"
    return
}
test18_getBranchName() {
    export JOB_NAME=LFS_CI_-_FB1506_-_Build
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "FB1506" "${value}"
    return
}
test19_getBranchName() {
    export LFS_CI_GLOBAL_LOCATION_NAME="abc"
    assertTrue "getLocationName"
    local value=$(getLocationName)
    assertEquals "abc" "${value}"
    return
}

test20_mustHaveLocationName() {
    assertTrue "mustHaveLocationName"
    return
}

test21_mustHaveLocationName() {
    unset JOB_NAME
    export JOB_NAME
    assertFalse "mustHaveLocationName"
    return
}
test22_mustHaveLocationName() {
    assertTrue "mustHaveLocationName"
    return
}

test23_mustHaveBranchName() {
    unset JOB_NAME
    export JOB_NAME
    assertFalse "mustHaveBranchName"
    return
}

test25_mustHaveTargetBoardName() {
    assertTrue "mustHaveTargetBoardName"
    return
}
test26_mustHaveTargetBoardName() {
    unset JOB_NAME
    export JOB_NAME
    assertFalse "mustHaveTargetBoardName"
    return
}

source lib/shunit2

exit 0
