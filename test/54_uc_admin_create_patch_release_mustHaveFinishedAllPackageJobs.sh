#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    export LFS_CI_CONFIG_FILE=$LFS_CI_ROOT/etc/development.cfg
    export BASE_BUILD="PS_LFS_OS_2015_08_01_001"
    export IMPORTANT_NOTE="BlaBla"
    export BUILD_USER_ID="1234"
    export BUILD_USER="Ich"

    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    getPackageBuildNumberFromFingerprint() {
        mockedCommand "getPackageBuildNumberFromFingerprint $@"
        if [[ "${1}" == "PS_LFS_OS_2015_08_01_9999" ]] ; then
            exit 1
        else
            echo 1234
        fi
    }

    return
}

setUp() {
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export BASE_BUILD="PS_LFS_OS_2015_08_01_0001"
    export FSMR2_PATCH_BUILD="PS_LFS_OS_2015_08_01_0002"
    export FSMR3_PATCH_BUILD="PS_LFS_OS_2015_08_01_0003"
    assertTrue "BASE:${BASE_BUILD}, FSMR2: ${FSMR2_PATCH_BUILD}, FSMR3: ${FSMR3_PATCH_BUILD}" "mustHaveFinishedAllPackageJobs"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getPackageBuildNumberFromFingerprint PS_LFS_OS_2015_08_01_0001
getPackageBuildNumberFromFingerprint PS_LFS_OS_2015_08_01_0002
getPackageBuildNumberFromFingerprint PS_LFS_OS_2015_08_01_0003
EOF
    assertExecutedCommands ${expect}

    return 
}

test2() {
    export BASE_BUILD="PS_LFS_OS_2015_08_01_0001"
    export FSMR2_PATCH_BUILD="PS_LFS_OS_2015_08_01_9999"
    export FSMR3_PATCH_BUILD="PS_LFS_OS_2015_08_01_0003"
    assertFalse "BASE:${BASE_BUILD}, FSMR2: ${FSMR2_PATCH_BUILD}, FSMR3: ${FSMR3_PATCH_BUILD}" "mustHaveFinishedAllPackageJobs"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getPackageBuildNumberFromFingerprint PS_LFS_OS_2015_08_01_0001
getPackageBuildNumberFromFingerprint PS_LFS_OS_2015_08_01_9999
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
