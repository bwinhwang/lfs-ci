#!/bin/bash

source test/common.sh
source lib/uc_ready_for_release.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace $@"
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
    }
    createReleaseLinkOnCiLfsShare() {
        mockedCommand "createReleaseLinkOnCiLfsShare $@"
    }
    createLatestReleaseOfBranchLinkOnCiLfsShare() {
        mockedCommand "createLatestReleaseOfBranchLinkOnCiLfsShare $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_READY_FOR_RELEASE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
mustHavePreparedWorkspace 
createReleaseLinkOnCiLfsShare 
createLatestReleaseOfBranchLinkOnCiLfsShare 
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
