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
    createWorkspace() {
        mockedCommand "createWorkspace"
    }
    updateWorkspace() {
        mockedCommand "updateWorkspace"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

testCreateOrUpdateWorkspace_withoutProblems() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    assertTrue "createOrUpdateWorkspace"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
createWorkspace
EOF
    assertExecutedCommands ${expect}
}

testCreateOrUpdateWorkspace_withoutProblems_withMinusU() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    assertTrue "createOrUpdateWorkspace -u"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
updateWorkspace
EOF
    assertExecutedCommands ${expect}
}

testCreateOrUpdateWorkspace_withoutProblems_withoutExistingWorkspace() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace

    assertTrue "createOrUpdateWorkspace -u"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
createWorkspace
EOF
    assertExecutedCommands ${expect}
}

testCreateOrUpdateWorkspace_invalidParameter() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace

    assertTrue  "createOrUpdateWorkspace -u"
    assertTrue  "createOrUpdateWorkspace --allowUpdate"
    assertFalse "createOrUpdateWorkspace --update"
    assertFalse "createOrUpdateWorkspace --u"
    assertFalse "createOrUpdateWorkspace --invalid"
}

source lib/shunit2

exit 0
