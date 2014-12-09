#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/createWorkspace.sh

export UNITTEST_COMMAND=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UNITTEST_COMMAND}
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
    getBuildJobNameFromUpstreamProject() {
        mockedCommand "getBuildJobNameFromUpstreamProject $@"
        echo "$1"
    }
    getBuildBuildNumberFromUpstreamProject() {
        mockedCommand "getBuildBuildNumberFromUpstreamProject $@"
        echo "123"
    }
    copyRevisionStateFileToWorkspace() {
        mockedCommand "copyRevisionStateFileToWorkspace $@"
        if [[ $1 == "createRevisionStateFile" ]] ; then
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
    cp -f /dev/null ${UNITTEST_COMMAND}
}

tearDown() {
    rm -rf ${UNITTEST_COMMAND}
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

    export UPSTREAM_PROJECT=createRevisionStateFile
    export UPSTREAM_BUILD=build

    # mock the copy revision file function
    assertTrue "latestRevisionFromRevisionStateFile"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
getBuildJobNameFromUpstreamProject createRevisionStateFile build
getBuildBuildNumberFromUpstreamProject createRevisionStateFile build
copyRevisionStateFileToWorkspace createRevisionStateFile 123
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

    # test for correct value
    local revision=$(latestRevisionFromRevisionStateFile)
    assertEquals "got expected revision" "3" "${revision}" 
}

source lib/shunit2

exit 0
