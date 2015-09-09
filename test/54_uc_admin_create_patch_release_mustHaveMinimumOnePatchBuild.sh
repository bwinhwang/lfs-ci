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
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0002

    assertTrue "FSMR2: ${FSMR2_PATCH_BUILD}" "mustHaveMinimumOnePatchBuild"
}

test2() {
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0002

    assertTrue "FSMR3: ${FSMR3_PATCH_BUILD}" "mustHaveMinimumOnePatchBuild"
}

test3() {
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0002

    assertTrue "FSMR4: ${FSMR4_PATCH_BUILD}" "mustHaveMinimumOnePatchBuild"
}

test4() {

    assertFalse "Test should fail if no patch build is given!" "mustHaveMinimumOnePatchBuild"
}

source lib/shunit2

exit 0
