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

testCreateOrUpdateWorkspace_withoutProblems() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    assertTrue "createOrUpdateWorkspace"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
createWorkspace
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"
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
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"
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
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"
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
