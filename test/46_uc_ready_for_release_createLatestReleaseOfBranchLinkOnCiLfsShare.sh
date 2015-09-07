#!/bin/bash

source test/common.sh
source lib/uc_ready_for_release.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getNextCiLabelName() {
        echo PS_LFS_OS_2015_07_01
    }
    getConfig() {
        echo $1
    }
    execute() {
        mockedCommand "execute $@"
    }
    getBranchName() {
        echo branchName
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "createLatestReleaseOfBranchLinkOnCiLfsShare"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustExistDirectory LFS_CI_UC_package_copy_to_share_real_location
mustExistDirectory LFS_CI_UC_package_copy_to_share_real_location/PS_LFS_OS_2015_07_01
execute rm -f LFS_CI_UC_package_copy_to_share_real_location/latest_branchName
execute ln -sf LFS_CI_UC_package_copy_to_share_real_location/PS_LFS_OS_2015_07_01 LFS_CI_UC_package_copy_to_share_real_location/latest_branchName
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
