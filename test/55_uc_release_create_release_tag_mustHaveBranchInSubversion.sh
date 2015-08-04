#!/bin/bash

source test/common.sh
source lib/uc_release_create_rel_tag.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    execute() {
        mockedCommand "execute $@"
    }
    getBranchName() {
        mockedCommand "getBranchName $@"
        echo "branch_name"
    }
    mustExistBranchInSubversion() {
        mockedCommand "mustExistBranchInSubversion $@"
    }
    shouldNotExistsInSubversion() {
        mockedCommand "shouldNotExistsInSubversion $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME
    export LFS_PROD_RELEASE_CURRENT_REL_TAG_NAME=PS_LFS_REL_BUILD_NAME
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_mustHaveBranchInSubversion"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_PROD_svn_delivery_release_repos_url -t tagName:LFS_PROD_RELEASE_CURRENT_TAG_NAME
getBranchName 
mustExistBranchInSubversion LFS_PROD_svn_delivery_release_repos_url tags
mustExistBranchInSubversion LFS_PROD_svn_delivery_release_repos_url branches
mustExistBranchInSubversion LFS_PROD_svn_delivery_release_repos_url/branches/ branch_name
shouldNotExistsInSubversion LFS_PROD_svn_delivery_release_repos_url/tags/ PS_LFS_REL_BUILD_NAME
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
