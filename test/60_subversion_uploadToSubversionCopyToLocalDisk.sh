#!/bin/bash

source test/common.sh
source lib/subversion.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            *) echo $1 ;;
        esac
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export JOB_NAME=LFS_PROD_-_trunk_-_Release_-_upload
    export BUILD_NUMBER=1234
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_2015_09_0001
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_uploadToSubversionCopyToLocalDisk /path/to/foo"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustExistDirectory /path/to/foo
execute mkdir -p /upload
execute rsync --delete -av /path/to/foo/ /upload/
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
