#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    # create a temp. Release_Candidates dir
    export UT_RELEASE_DIR=$(createTempDirectory)

    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0010
    mkdir -p $UT_RELEASE_DIR/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0001

    # create a temp file.cfg
    export UT_CFG_FILE=$(createTempFile)
    echo "LFS_CI_UC_package_copy_to_share_name < productName:LFS   > = ${UT_RELEASE_DIR}"                                                           >> ${UT_CFG_FILE}

    echo "LFS_CI_UC_package_copy_to_share_path_name <                          > = Release_Candidates/FSMr3"                                        >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < location:FSM_R4_DEV      > = Release_Candidates/FSMr4"                                        >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < location~LRC             > = Release_Candidates/LRC"                                          >> ${UT_CFG_FILE}
    echo "LFS_CI_UC_package_copy_to_share_path_name < productName:LTK          > = Release_Candidates/LTK"                                          >> ${UT_CFG_FILE}

    echo 'LFS_CI_UC_package_copy_to_share_real_location <> = ${LFS_CI_UC_package_copy_to_share_name}/${LFS_CI_UC_package_copy_to_share_path_name}'  >> ${UT_CFG_FILE}

    echo 'LFS_hw_platforms <> = fsmr2 fsmr3 fsmr4'  >> ${UT_CFG_FILE}

    echo 'LFS_release_os_dirs < hw_platform:fsmr2 > = sys-root_powerpc-e500-linux-gnu sys-root_i686-pc-linux-gnu platforms_fcmd platforms_fspc platforms_qemu addons_powerpc-e500-linux-gnu'  >> ${UT_CFG_FILE}
    echo 'LFS_release_os_dirs < hw_platform:fsmr3 > = sys-root_mips64-octeon2-linux-gnu sys-root_x86_64-pc-linux-gnu platforms_fsm3_octeon2 platforms_qemu_64 addons_mips64-octeon2-linux-gnu addons_x86_64-pc-linux-gnu'  >> ${UT_CFG_FILE}
    echo 'LFS_release_os_dirs < hw_platform:fsmr4 > = sys-root_arm-cortexa15-linux-gnueabihf platforms_fsm4_axm platforms_fsm4_k2 addons_arm-cortexa15-linux-gnueabihf'  >> ${UT_CFG_FILE}

    echo 'LFS_release_os_subdir < hw_platform:fsmr2, os_dir:sys-root_powerpc-e500-linux-gnu        > = os/sys-root/powerpc-e500-linux-gnu'         >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr2, os_dir:sys-root_i686-pc-linux-gnu             > = os/sys-root/i686-pc-linux-gnu'              >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr2, os_dir:platforms_fcmd                         > = os/platforms/fcmd'                          >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr2, os_dir:platforms_fspc                         > = os/platforms/fspc'                          >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr2, os_dir:platforms_qemu                         > = os/platforms/qemu'                          >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr2, os_dir:addons_powerpc-e500-linux-gnu          > = os/addons/powerpc-e500-linux-gnu'           >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr3, os_dir:sys-root_mips64-octeon2-linux-gnu      > = os/sys-root/mips64-octeon2-linux-gnu'       >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr3, os_dir:sys-root_x86_64-pc-linux-gnu           > = os/sys-root/x86_64-pc-linux-gnu'            >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr3, os_dir:platforms_fsm3_octeon2                 > = os/platforms/fsm3_octeon2'                  >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr3, os_dir:platforms_qemu_64                      > = os/platforms/qemu_64'                       >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr3, os_dir:addons_mips64-octeon2-linux-gnu        > = os/addons/mips64-octeon2-linux-gnu'         >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr3, os_dir:addons_x86_64-pc-linux-gnu             > = os/addons/x86_64-pc-linux-gnu'              >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr4, os_dir:sys-root_arm-cortexa15-linux-gnueabihf > = os/sys-root/arm-cortexa15-linux-gnueabihf'  >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr4, os_dir:platforms_fsm4_axm                     > = os/platforms/fsm4_axm'                      >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr4, os_dir:platforms_fsm4_k2                      > = os/platforms/fsm4_k2'                       >> ${UT_CFG_FILE}
    echo 'LFS_release_os_subdir < hw_platform:fsmr4, os_dir:addons_arm-cortexa15-linux-gnueabihf   > = os/addons/arm-cortexa15-linux-gnueabihf'    >> ${UT_CFG_FILE}


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

test_with_base_build() {
    BASE_BUILD=PS_LFS_OS_2015_08_0010

    assertTrue "copyPatchBuildsIntoBaseBuild finished with error!" "copyPatchBuildsIntoBaseBuild"

    return
}

test_without_base_build() {
    unset BASE_BUILD

    assertFalse "copyPatchBuildsIntoBaseBuild should fail but was executed successfully!" "copyPatchBuildsIntoBaseBuild"

    return
}

source lib/shunit2

exit 0
