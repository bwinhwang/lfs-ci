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
    getBranchName() {
        mockedCommand "getBranchName $@"
        echo "branch_name"
    }
    svnCheckout() {
        mockedCommand "svnCheckout $@"
    }
    svnPropSet() {
        mockedCommand "svnPropSet $@"
    }
    svnCommit() {
        mockedCommand "svnCommit $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME
    export LFS_PROD_RELEASE_CURRENT_REL_TAG_NAME=PS_LFS_REL_BUILD_NAME
    mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-summary
    touch ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_createReleaseTag_setSvnExternals"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getBranchName 
getConfig LFS_PROD_svn_delivery_repos_name -t tagName:PS_LFS_OS_BUILD_NAME
getConfig sdk2 -f ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
getConfig sdk3 -f ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
getConfig sdk -f ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
getConfig LFS_uc_release_create_release_tag_sdk_external_line -t sdk:sdk -t sdk2:sdk2 -t sdk3:sdk3
svnCheckout --ignore-externals /branches/branch_name ${WORKSPACE}/workspace/svn
svnPropSet svn:externals -F ${WORKSPACE}/workspace/svnExternals ${WORKSPACE}/workspace/svn/
getConfig LFS_PROD_uc_release_svn_message_prefix
svnCommit -F ${WORKSPACE}/workspace/commitMessagge ${WORKSPACE}/workspace/svn/
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
