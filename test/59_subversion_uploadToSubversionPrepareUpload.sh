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
            LFS_CI_uc_release_can_commit_depencencies) echo ${UT_CAN_COMMIT} ;;
            OS_ramdisk) echo ${UT_RAM_DISK} ;;
            *) echo $1 ;;
        esac
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustHaveFreeDiskSpace() {
        mockedCommand "mustHaveFreeDiskSpace $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UT_RAM_DISK=$(createTempDirectory)
    mkdir -p ${UT_RAM_DISK}/tmp

    export UPLOAD_DIR=$(createTempDirectory)
    export JOB_NAME=job_name
    export USER=userName

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # assertTrue "_uploadToSubversionPrepareUpload"
    _uploadToSubversionPrepareUpload

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig OS_ramdisk
execute rm -rf ${UT_RAM_DISK}/job_name.userName/tmp
execute mkdir -p ${UT_RAM_DISK}/job_name.userName/tmp
getConfig LFS_PROD_uc_release_upload_to_subversion_free_space_on_ramdisk
mustHaveFreeDiskSpace ${UT_RAM_DISK}/job_name.userName/tmp LFS_PROD_uc_release_upload_to_subversion_free_space_on_ramdisk
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
