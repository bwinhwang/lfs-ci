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
    mustHaveNextLabelName() {
        mockedCommand "mustHaveNextLabelName $@"
        export LFS_CI_NEXT_LABEL_NAME=BUILD_NAME
    }
    mustExistBranchInSubversion() {
        mockedCommand "mustExistBranchInSubversion $@"
    }
    mustHaveFreeDiskSpace() {
        mockedCommand "mustHaveFreeDiskSpace $@"
    }
    _uploadToSubversionPrepareUpload() {
        mockedCommand "_uploadToSubversionPrepareUpload $@"
    }
    _uploadToSubversionCopyToLocalDisk() {
        mockedCommand "_uploadToSubversionCopyToLocalDisk $@"
    }
    _uploadToSubversionCheckoutWorkspace() {
        mockedCommand "_uploadToSubversionCheckoutWorkspace $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UT_RAM_DISK=$(createTempDirectory)

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
    assertTrue "uploadToSubversion ${UPLOAD_DIR} http://svne1/BTS_D_SC_LFS os/branches os/tags/T1 'message to commit'"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_PROD_uc_release_upload_to_subversion_sleep_time_after_commit
mustExistBranchInSubversion http://svne1/BTS_D_SC_LFS os/branches
_uploadToSubversionPrepareUpload 
_uploadToSubversionCopyToLocalDisk ${UPLOAD_DIR}
_uploadToSubversionCheckoutWorkspace http://svne1/BTS_D_SC_LFS/os/branches
mustExistBranchInSubversion http://svne1/BTS_D_SC_LFS os/tags
execute -r 3 ${LFS_CI_ROOT}/lib/contrib/svn_load_dirs/svn_load_dirs.pl -t os/tags/T1 -message 'message to commit' -v -no_user_input -no_diff_tag -glob_ignores=#.# -sleep LFS_PROD_uc_release_upload_to_subversion_sleep_time_after_commit http://svne1/BTS_D_SC_LFS os/branches ${UPLOAD_DIR}
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    assertTrue "uploadToSubversion ${UPLOAD_DIR} http://svne1/BTS_D_SC_LFS os/branches os/tags/T1 "

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_PROD_uc_release_upload_to_subversion_sleep_time_after_commit
mustExistBranchInSubversion http://svne1/BTS_D_SC_LFS os/branches
_uploadToSubversionPrepareUpload 
_uploadToSubversionCopyToLocalDisk ${UPLOAD_DIR}
_uploadToSubversionCheckoutWorkspace http://svne1/BTS_D_SC_LFS/os/branches
mustExistBranchInSubversion http://svne1/BTS_D_SC_LFS os/tags
execute -r 3 ${LFS_CI_ROOT}/lib/contrib/svn_load_dirs/svn_load_dirs.pl -t os/tags/T1 -v -no_user_input -no_diff_tag -glob_ignores=#.# -sleep LFS_PROD_uc_release_upload_to_subversion_sleep_time_after_commit http://svne1/BTS_D_SC_LFS os/branches ${UPLOAD_DIR}
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    assertTrue "uploadToSubversion ${UPLOAD_DIR} http://svne1/BTS_D_SC_LFS os/branches"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_PROD_uc_release_upload_to_subversion_sleep_time_after_commit
mustExistBranchInSubversion http://svne1/BTS_D_SC_LFS os/branches
_uploadToSubversionPrepareUpload 
_uploadToSubversionCopyToLocalDisk ${UPLOAD_DIR}
_uploadToSubversionCheckoutWorkspace http://svne1/BTS_D_SC_LFS/os/branches
execute -r 3 ${LFS_CI_ROOT}/lib/contrib/svn_load_dirs/svn_load_dirs.pl -v -no_user_input -no_diff_tag -glob_ignores=#.# -sleep LFS_PROD_uc_release_upload_to_subversion_sleep_time_after_commit http://svne1/BTS_D_SC_LFS os/branches ${UPLOAD_DIR}
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
