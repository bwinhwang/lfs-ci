#!/bin/bash

source test/common.sh

source lib/createWorkspace.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    exit_handler() {
        echo exit
    }
    mustHaveValue() {
        mockedCommand "mustHaveValue $@"
        return
    }
    createWorkspace() {
        mockedCommand "createWorkspace"
    }
    updateWorkspace() {
        mockedCommand "updateWorkspace"
    }
    getBuildJobNameFromFingerprint() {
        mockedCommand "getBuildJobNameFromFingerprint $@"
        echo ${UT_JOB_NAME}
    }
    getBuildBuildNumberFromFingerprint() {
        mockedCommand "getBuildBuildNumberFromFingerprint $@"
        echo "123"
    }
    copyRevisionStateFileToWorkspace() {
        mockedCommand "copyRevisionStateFileToWorkspace $@"
        if [[ $1 == "LFS_CI_-_trunk_-_Build" ]] ; then
            cat <<EOF > ${WORKSPACE}/revisions.txt
src-abc http://svnurl/src-abc 1
src-foo http://svnurl/src-foo 2
src-bar http://svnurl/src-bar 3
EOF
        fi
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export UT_JOB_NAME=LFS_CI_-_branch_-_Build
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

testLatestRevisionFromRevisionStateFile_withoutProblem() {
    export WORKSPACE=$(createTempDirectory)

    export UPSTREAM_PROJECT=project
    export UPSTREAM_BUILD=build

    cat <<EOF > ${WORKSPACE}/revisions.txt
src-abc http://svnurl/src-abc 1
src-foo http://svnurl/src-foo 2
src-bar http://svnurl/src-bar 3
EOF
    assertTrue "latestRevisionFromRevisionStateFile"

    # test for correct value
    local revision=$(latestRevisionFromRevisionStateFile)
    assertEquals "got expected revision" "3" "${revision}" 
}

testLatestRevisionFromRevisionStateFile_withoutProblem_withOutFile() {
    export WORKSPACE=$(createTempDirectory)

    export UPSTREAM_PROJECT=project
    export UPSTREAM_BUILD=build

    assertTrue "latestRevisionFromRevisionStateFile"

    # test for correct value
    local revision=$(latestRevisionFromRevisionStateFile)
    assertEquals "got expected revision" "" "${revision}" 
}


testLatestRevisionFromRevisionStateFile_withoutProblem_revisionFileDoesNotExist() {
    export WORKSPACE=$(createTempDirectory)
    export UT_JOB_NAME=LFS_CI_-_trunk_-_Build

    export UPSTREAM_PROJECT=createRevisionStateFile
    export UPSTREAM_BUILD=build

    # mock the copy revision file function
    assertTrue "latestRevisionFromRevisionStateFile"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getBuildJobNameFromFingerprint 
getBuildBuildNumberFromFingerprint 
copyRevisionStateFileToWorkspace LFS_CI_-_trunk_-_Build 123
EOF
    assertExecutedCommands ${expect}

    # test for correct value
    local revision=$(latestRevisionFromRevisionStateFile)
    assertEquals "got expected revision" "3" "${revision}" 
}

source lib/shunit2

exit 0
