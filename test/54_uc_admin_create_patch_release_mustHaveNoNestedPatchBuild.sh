#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    # create a temp. Release_Candidates dir
    export UT_RELEASE_DIR=$(createTempDirectory)
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0020/os/doc
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0010/os/doc
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0001/os/doc
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0002/os/doc
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0003/os/doc
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0004/os/doc

    # patch this release
    touch $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0020/os/doc/patched_build.xml
    touch $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0004/os/doc/patched_build.xml

    # create a temp file.cfg
    export UT_CFG_FILE=$(createTempFile)
    echo "LFS_CI_UC_package_copy_to_share_name < productName:LFS   > = ${UT_RELEASE_DIR}"                                                           >> ${UT_CFG_FILE}

    echo "LFS_CI_UC_package_copy_to_share_path_name <                          > = Release_Candidates/FSMr3"                                        >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < location:FSM_R4_DEV      > = Release_Candidates/FSMr4"                                        >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < location~LRC             > = Release_Candidates/LRC"                                          >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < productName:LTK          > = Release_Candidates/LTK"                                          >> ${UT_CFG_FILE}

    echo 'LFS_CI_UC_package_copy_to_share_real_location <> = ${LFS_CI_UC_package_copy_to_share_name}/${LFS_CI_UC_package_copy_to_share_path_name}'  >> ${UT_CFG_FILE}
    export LFS_CI_CONFIG_FILE=${UT_CFG_FILE}

    return
}

oneTimeTearDown() {
    rm -rf ${UT_RELEASE_DIR}
}

setUp() {
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS
    return
}

tearDown() {
    return
}

test_setup() {
    cat ${LFS_CI_CONFIG_FILE}

    tree ${UT_RELEASE_DIR}

    echo LFS_CI_CONFIG_FILE=${LFS_CI_CONFIG_FILE}
    echo UT_RELEASE_DIR=${UT_RELEASE_DIR}
}

test_unpatched_base_and_three_unpatched_patch_releases() {
    # all 3 patch builds not patched
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0002
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0003

    assertTrue "BASE:${BASE_BUILD}, FSMR2: ${FSMR2_PATCH_BUILD},  FSMR3: ${FSMR3_PATCH_BUILD} FSMR4: ${FSMR4_PATCH_BUILD}" \
               "mustHaveNoNestedPatchBuild"

    return
}

test_unpatched_base_and_one_unpatched_patch_release() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0001

    assertTrue "BASE:${BASE_BUILD}, FSMR4: ${FSMR4_PATCH_BUILD}" "mustHaveNoNestedPatchBuild"

    return
}

test_unpatched_base_and_one_patched_patch_release() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0004
    FSMR4_PATCH_BUILD=

    assertFalse "BASE:${BASE_BUILD}, FSMR3: ${FSMR3_PATCH_BUILD}" "mustHaveNoNestedPatchBuild"

    return
}

test_patched_base_and_one_unpatched_patch_release() {
    BASE_BUILD=PS_LFS_OS_2015_08_0020
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR4_PATCH_BUILD=

    assertFalse "BASE:${BASE_BUILD}, FSMR3: ${FSMR3_PATCH_BUILD}" "mustHaveNoNestedPatchBuild"

    return
}


source lib/shunit2

exit 0
