#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    # create a temp. Release_Candidates dir
    export UT_RELEASE_DIR=$(createTempDirectory)
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0010/os/doc/
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0001/os/doc/

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
    return 
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

test_with_base_build_and_one_patch_build() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010
    FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0001
    BUILD_USER="Peter Pan"
    IMPORTANT_NOTE="bla bla "

    assertTrue "markBaseBuildAsPatched failed!" "markBaseBuildAsPatched"
    assertTrue ".../os/doc/patched_build.xml not found!" "[[ -f $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0010/os/doc/patched_build.xml ]]"

    return
}

test_without_base_build() {
    unset BASE_BUILD

    assertFalse "markBaseBuildAsPatched should fail but was executed successfully!" "markBaseBuildAsPatched"

    return
}

source lib/shunit2

exit 0
