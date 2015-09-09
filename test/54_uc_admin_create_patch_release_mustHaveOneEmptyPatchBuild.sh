#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    return
}

setUp() {
    return
}

tearDown() {
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=
    return
}

test1() {
    # FSMR2 is empty 
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertTrue "FSMR2_PATCH_BUILD=${FSMR2_PATCH_BUILD=}" "mustHaveOneEmptyPatchBuild"
}

test2() {
    # FSMR3 is empty 
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertTrue "FSMR3_PATCH_BUILD=${FSMR3_PATCH_BUILD=}" "mustHaveOneEmptyPatchBuild"
}

test3() {
    # FSMR4 is empty 
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertTrue "FSMR4_PATCH_BUILD=${FSMR4_PATCH_BUILD=}" "mustHaveOneEmptyPatchBuild"
}

test4() {
    # all patch builds are empty

    assertTrue "FSMR2: ${FSMR2_PATCH_BUILD=} FSMR3: ${FSMR3_PATCH_BUILD=} FSMR4: ${FSMR4_PATCH_BUILD=}" "mustHaveOneEmptyPatchBuild"
}

test5() {
    # no patch build is empty
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertFalse "FSMR2: ${FSMR2_PATCH_BUILD=} FSMR3: ${FSMR3_PATCH_BUILD=} FSMR4: ${FSMR4_PATCH_BUILD=}" "mustHaveOneEmptyPatchBuild"
}

source lib/shunit2

exit 0
