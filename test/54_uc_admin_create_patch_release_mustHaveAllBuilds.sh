#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    getConfig() {
        mockedCommand "getConfig $@"
        case ${1} in
            LFS_CI_UC_package_copy_to_share_real_location)  echo ${UT_CI_LFS_SHARE} ;;
            *)                                              echo $1
        esac
    }

    export UT_CI_LFS_SHARE=$(createTempDirectory)
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0001
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0002
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0003
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0004
    tree ${UT_CI_LFS_SHARE}

    return
}

setUp() {

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    BASE_BUILD=
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=
    return
}

test1() {
    # all builds exist 
    BASE_BUILD=PS_LFS_OS_2015_08_0001
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0002
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0003
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0004

    assertTrue "at least one build was not found on share!" "mustHaveAllBuilds"
}

test2() {
    # BASE_BUILD does not exist
    BASE_BUILD=PS_LFS_OS_9999_08_0001

    assertFalse "${BASE_BUILD} should not be found on share!" "mustHaveAllBuilds"
}

test3() {
    # FSMR2_PATCH_BUILD does not
    FSMR2_PATCH_BUILD=PS_LFS_OS_9999_08_0001

    assertFalse "${FSMR2_PATCH_BUILD} should not be found on share!" "mustHaveAllBuilds"
}

test4() {
    # FSMR3_PATCH_BUILD does not
    FSMR3_PATCH_BUILD=PS_LFS_OS_9999_08_0001

    assertFalse "${FSMR3_PATCH_BUILD} should not be found on share!" "mustHaveAllBuilds"
}

test5() {
    # FSMR4_PATCH_BUILD does not
    FSMR4_PATCH_BUILD=PS_LFS_OS_9999_08_0001

    assertFalse "${FSMR4_PATCH_BUILD} should not be found on share!" "mustHaveAllBuilds"
}

source lib/shunit2

exit 0
