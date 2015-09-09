#!/bin/bash

source test/common.sh
source lib/common.sh

oneTimeSetUp() {
    export UT_CFG_FILE=$(createTempFile)
    echo "LFS_PROD_tag_to_branch < productName:LFS,   tagName~MD1_PS_LFS_OS_2015_07_\d\d\d\d               > = MD11507"     >> ${UT_CFG_FILE}
    echo "LFS_PROD_tag_to_branch < productName:LFS,   tagName~FB_PS_LFS_OS_2015_07_\d\d\d\d                > = FB1507"      >> ${UT_CFG_FILE}
    echo "LFS_PROD_tag_to_branch < productName:LFS,   tagName~FB_LRC_LCP_PS_LFS_OS_2014_11_\d\d\d\d        > = LRC_FB1411"  >> ${UT_CFG_FILE}
    echo "LFS_PROD_tag_to_branch < productName:LFS,   tagName~LRC_LCP_PS_LFS_OS_\d\d\d\d_\d\d_\d\d\d\d     > = LRC       "  >> ${UT_CFG_FILE}
    echo "LFS_PROD_tag_to_branch < productName:LFS,   tagName~PS_LFS_OS_\d\d\d\d_\d\d_\d\d\d\d             > = trunk"       >> ${UT_CFG_FILE}

    export LFS_CI_CONFIG_FILE=${UT_CFG_FILE}

    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    return
}

setUp() {
#    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS
    return
}

tearDown() {
#    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test_trunk() {
    assertEquals "$(getBranchNameFromBuildName PS_LFS_OS_2015_07_0224)" \
                 "trunk"
    return
}

test_FB1507() {
    assertEquals "$(getBranchNameFromBuildName FB_PS_LFS_OS_2015_07_0123)" \
                 "FB1507"
    return
}

test_MD11507() {
    assertEquals "$(getBranchNameFromBuildName MD1_PS_LFS_OS_2015_07_0124)" \
                 "MD11507"
    return
}

test_LRC() {
    assertEquals "$(getBranchNameFromBuildName LRC_LCP_PS_LFS_OS_2015_07_0124)" \
                 "LRC"
    return
}

test_LRC_FB1411() {
    assertEquals "$(getBranchNameFromBuildName FB_LRC_LCP_PS_LFS_OS_2014_11_0018)" \
                 "LRC_FB1411"
    return
}

source lib/shunit2

exit 0

