#!/bin/bash

source test/common.sh
source lib/uc_release_upload_to_svn.sh

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
    mustBePreparedForReleaseTask() {
        mockedCommand "mustBePreparedForReleaseTask $@"
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    uploadToSubversion() {
        mockedCommand "uploadToSubversion $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export JOB_NAME=LFS_PROD_-_trunk_-_Release_-_upload
    export BUILD_NUMBER=1234
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # assertTrue "usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION"
    usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
getConfig LFS_CI_UC_package_copy_to_share_real_location
mustExistDirectory LFS_CI_UC_package_copy_to_share_real_location/
uploadToSubversion LFS_CI_UC_package_copy_to_share_real_location//os
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
