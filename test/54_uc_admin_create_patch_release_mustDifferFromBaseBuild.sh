#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {

    return
}

setUp() {
    export UT_CI_LFS_SHARE=$(createTempDirectory)
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0001
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0002
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0003
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0004
    return
}

tearDown() {
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=
    return
}

test1() {
    # all builds are different from BASE_BUILD
    BASE_BUILD=PS_LFS_OS_2015_08_0001
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0002
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0003
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0004

    assertTrue "BASE:${BASE_BUILD}, FSMR2:${FSMR2_PATCH_BUILD}, FSMR3:${FSMR3_PATCH_BUILD}, FSMR4:${FSMR4_PATCH_BUILD}" \
               "mustDifferFromBaseBuild"
}

test2() {
    # FSMR2_PATCH_BUILD is same as BASE_BUILD
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertFalse "BASE:${BASE_BUILD}, FSMR2:${FSMR2_PATCH_BUILD}" "mustDifferFromBaseBuild"
}

test3() {
    # FSMR3_PATCH_BUILD is same as BASE_BUILD
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertFalse "BASE:${BASE_BUILD}, FSMR3:${FSMR3_PATCH_BUILD}" "mustDifferFromBaseBuild"
}

test4() {
    # FSMR4_PATCH_BUILD is same as BASE_BUILD
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertFalse "BASE:${BASE_BUILD}, FSMR4:${FSMR4_PATCH_BUILD}" "mustDifferFromBaseBuild"
}

source lib/shunit2

exit 0
