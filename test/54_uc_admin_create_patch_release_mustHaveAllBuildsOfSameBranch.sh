#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    # create a temp. Release_Candidates dir
    export UT_RELEASE_DIR=$(createTempDirectory)
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0010
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0001
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0002
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0003
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/FB_PS_LFS_OS_2015_08_0010
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/MD1_PS_LFS_OS_2015_08_0010
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/LRC_PS_LFS_OS_2015_08_0010
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/LRC_LCP_PS_LFS_OS_2015_08_0010
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/FB_LRC_LCP_PS_LFS_OS_2014_11_0010

    # create a temp file.cfg
    export UT_CFG_FILE=$(createTempFile)
    echo "LFS_CI_UC_package_copy_to_share_name < productName:LFS   > = ${UT_RELEASE_DIR}"                                                           >> ${UT_CFG_FILE}

    echo "LFS_CI_UC_package_copy_to_share_path_name <                          > = Release_Candidates/FSMr3"                                        >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < location:FSM_R4_DEV      > = Release_Candidates/FSMr4"                                        >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < location~LRC             > = Release_Candidates/LRC"                                          >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < productName:LTK          > = Release_Candidates/LTK"                                          >> ${UT_CFG_FILE}

    echo 'LFS_CI_UC_package_copy_to_share_real_location <> = ${LFS_CI_UC_package_copy_to_share_name}/${LFS_CI_UC_package_copy_to_share_path_name}'  >> ${UT_CFG_FILE}

    echo 'LFS_PROD_tag_to_branch < productName:LFS,   tagName~MD1_PS_LFS_OS_2015_08_\d\d\d\d               > = MD11508'                             >> ${UT_CFG_FILE}
    echo 'LFS_PROD_tag_to_branch < productName:LFS,   tagName~FB_PS_LFS_OS_2015_08_\d\d\d\d                > = FB1508'                              >> ${UT_CFG_FILE}
    echo 'LFS_PROD_tag_to_branch < productName:LFS,   tagName~FB_LRC_LCP_PS_LFS_OS_2014_11_\d\d\d\d        > = LRC_FB1411'                          >> ${UT_CFG_FILE}
    echo 'LFS_PROD_tag_to_branch < productName:LFS,   tagName~LRC_LCP_PS_LFS_OS_\d\d\d\d_\d\d_\d\d\d\d     > = LRC'                                 >> ${UT_CFG_FILE}
    echo 'LFS_PROD_tag_to_branch < productName:LFS,   tagName~PS_LFS_OS_\d\d\d\d_\d\d_\d\d\d\d             > = trunk'                               >> ${UT_CFG_FILE}

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

test_base_and_three_patch_releases_from_same_branch() {
    # all 3 patch builds from same branch
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0002
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0003

    assertTrue "BASE:${BASE_BUILD}, FSMR2:${FSMR2_PATCH_BUILD}, FSMR3:${FSMR3_PATCH_BUILD}, FSMR4:${FSMR4_PATCH_BUILD}" \
                "mustHaveAllBuildsOfSameBranch"

    return
}

test_base_and_two_patch_releases_from_same_branch() {
    # 2 patch builds from same branch
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0002

    assertTrue "BASE:${BASE_BUILD}, FSMR2:${FSMR2_PATCH_BUILD}, FSMR4:${FSMR4_PATCH_BUILD}" "mustHaveAllBuildsOfSameBranch"

    return
}

test_only_base_release_given() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=

    assertTrue "BASE:${BASE_BUILD}" "mustHaveAllBuildsOfSameBranch"

    return
}

test_base_and_one_patch_release_fb_branch() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    FSMR3_PATCH_BUILD=FB_PS_LFS_OS_2015_08_0010
    FSMR4_PATCH_BUILD=PS_LFS_OS_2015_08_0002

    assertFalse "BASE:${BASE_BUILD}, FSMR3:${FSMR3_PATCH_BUILD}" "mustHaveAllBuildsOfSameBranch"

    return
}

test_base_and_one_patch_release_md1_branch() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=MD1_PS_LFS_OS_2015_08_0010
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=

    assertFalse "BASE:${BASE_BUILD}, FSMR2:${FSMR2_PATCH_BUILD}" "mustHaveAllBuildsOfSameBranch"

    return
}

test_base_and_one_patch_release_LRC_branch() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=LRC_LCP_PS_LFS_OS_2015_08_0010

    assertFalse "BASE:${BASE_BUILD}, FSMR4:${FSMR4_PATCH_BUILD}" "mustHaveAllBuildsOfSameBranch"

    return
}

test_base_and_one_patch_release_LRC_FB_branch() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR2_PATCH_BUILD=
    FSMR3_PATCH_BUILD=
    FSMR4_PATCH_BUILD=FB_LRC_LCP_PS_LFS_OS_2014_11_0010

    assertFalse "BASE:${BASE_BUILD}, FSMR4:${FSMR4_PATCH_BUILD}" "mustHaveAllBuildsOfSameBranch"

    return
}

source lib/shunit2

exit 0
