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
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)

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
    assertTrue "uploadToSubversion ${UPLOAD_DIR}"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextLabelName 
getConfig LFS_PROD_svn_delivery_release_repos_url -t tagName:BUILD_NAME
getConfig LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch
mustExistBranchInSubversion LFS_PROD_svn_delivery_release_repos_url os
mustExistBranchInSubversion LFS_PROD_svn_delivery_release_repos_url/os branches
mustExistBranchInSubversion LFS_PROD_svn_delivery_release_repos_url/os tags
mustExistBranchInSubversion LFS_PROD_svn_delivery_release_repos_url/os/branches LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch
execute mkdir -p /dev/shm/job_name.userName/tmp
mustHaveFreeDiskSpace /dev/shm/job_name.userName/tmp 15000000
execute rm -rf /dev/shm/job_name.userName/tmp
execute mkdir -p /dev/shm/job_name.userName/tmp
execute mkdir -p /dev/shm/job_name.userName/tmp/upload
execute rsync --delete -av ${UPLOAD_DIR}/ /dev/shm/job_name.userName/tmp/upload/
execute mkdir -p /dev/shm/job_name.userName/tmp/workspace
execute -r 3 svn --non-interactive --trust-server-cert checkout LFS_PROD_svn_delivery_release_repos_url/os/branches/LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch /dev/shm/job_name.userName/tmp/workspace
execute -r 3 ${LFS_CI_ROOT}/lib/contrib/svn_load_dirs/svn_load_dirs.pl -v -t os/tags/BUILD_NAME -wc /dev/shm/job_name.userName/tmp/workspace -no_user_input -no_diff_tag -glob_ignores=#.# -sleep 60 LFS_PROD_svn_delivery_release_repos_url os/branches/LFS_PROD_uc_release_upload_to_subversion_map_location_to_branch /dev/shm/job_name.userName/tmp/upload
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
