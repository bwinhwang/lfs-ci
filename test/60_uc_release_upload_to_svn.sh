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
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_2015_09_0001
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_RELEASE_UPLOAD_TO_SUBVERSION"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
getConfig LFS_CI_UC_package_copy_to_share_real_location
mustExistDirectory LFS_CI_UC_package_copy_to_share_real_location/PS_LFS_OS_2015_09_0001
getConfig LFS_PROD_svn_delivery_release_repos_urjl -t tagName:PS_LFS_OS_2015_09_0001
getConfig LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch
uploadToSubversion LFS_CI_UC_package_copy_to_share_real_location/PS_LFS_OS_2015_09_0001/os LFS_PROD_svn_delivery_release_repos_urjl os/LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch tags/PS_LFS_OS_2015_09_0001 upload of new lfs build PS_LFS_OS_2015_09_0001
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
