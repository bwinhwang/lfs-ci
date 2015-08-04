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
    mustBePreparedForReleaseTask() {
        mockedCommand "mustBePreparedForReleaseTask $@"
        export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME
        export LFS_PROD_RELEASE_CURRENT_REL_TAG_NAME=PS_LFS_REL_BUILD_NAME
    }
    getNextCiLabelName() {
        mockedCommand "getNextCiLabelName $@"
        echo "build_name"
    }
    getBranchName() {
        mockedCommand "getBranchName $@"
        echo "branch_name"
    }
    _createReleaseTag() {
        mockedCommand "_createReleaseTag $@"
    }
    _createReleaseTag_setSvnExternals() {
        mockedCommand "_createReleaseTag_setSvnExternals $@"
    }
    _mustHaveBranchInSubversion() {
        mockedCommand "_mustHaveBranchInSubversion $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_RELEASE_CREATE_RELEASE_TAG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
_mustHaveBranchInSubversion 
_createReleaseTag_setSvnExternals 
_createReleaseTag 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
