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
            LFS_CI_UC_package_copy_to_share_name)           echo ${UT_CI_LFS_SHARE} ;;
            *)                                              echo $1
        esac
    }

    export UT_CI_LFS_SHARE=$(createTempDirectory)
    mkdir -p ${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0001
    mkdir -p ${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0002
    mkdir -p ${UT_CI_LFS_SHARE}/Release
    ln -s ${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0001 ${UT_CI_LFS_SHARE}/Release/PS_LFS_REL_2015_08_0001 
    tree ${UT_CI_LFS_SHARE}

    return
}

setUp() {
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # BASE_BUILD has already been released
    BASE_BUILD=PS_LFS_OS_2015_08_0001

    assertFalse "BASE_BUILD: ${BASE_BUILD}" "mustBeUnreleasedBaseBuild"
}

test2() {
    # BASE_BUILD has not yet been released
    BASE_BUILD=PS_LFS_OS_2015_08_0002


    assertTrue "BASE_BUILD: ${BASE_BUILD}" "mustBeUnreleasedBaseBuild"
}


source lib/shunit2

exit 0
