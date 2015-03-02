#!/bin/bash

source test/common.sh

source lib/package.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    svnExport() {
        mockedCommand "svnExport $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            LFS_CI_UC_package_copy_to_share_name) echo ${UT_SDK_SHARE}  ;;
            LFS_CI_UC_package_sdk_svn_location)   echo http://svnSDKurl ;;
        esac
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_abc_-_abc
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_SDK_SHARE=$(createTempDirectory)

    assertTrue "mustHaveSdkOnShare SDK_BASELINE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_UC_package_copy_to_share_name
mustExistDirectory ${UT_SDK_SHARE}
mustExistDirectory ${UT_SDK_SHARE}/SDKs
getConfig LFS_CI_UC_package_sdk_svn_location
svnExport http://svnSDKurl/tags/SDK_BASELINE ${UT_SDK_SHARE}/SDKs/SDK_BASELINE
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_SDK_SHARE=$(createTempDirectory)
    mkdir -p ${UT_SDK_SHARE}/SDKs
    mkdir -p ${UT_SDK_SHARE}/SDKs/SDK_BASELINE

    assertTrue "mustHaveSdkOnShare SDK_BASELINE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_UC_package_copy_to_share_name
mustExistDirectory ${UT_SDK_SHARE}
mustExistDirectory ${UT_SDK_SHARE}/SDKs
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
