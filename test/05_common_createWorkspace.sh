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
    falseCommand() {
        mockedCommand "falseCommand" 
        return 1
    }
    trueCommand() {
        mockedCommand "trueCommand"
        return
    }
    sleep() {
        mockedCommand "sleep $@"
    }

    setupNewWorkspace() {
        mkdir -p ${WORKSPACE}/workspace/.build_workdir
    }
    mustHaveValue() {
        mockedCommand "mustHaveValue $@"
        return
    }
    switchSvnServerInLocations() {
        mockedCommand "switchSvnServerInLocations $@"
    }
    latestRevisionFromRevisionStateFile() {
        mockedCommand "latestRevisionFromRevisionStateFile $@"
        echo 12345
    }
    checkoutSubprojectDirectories() {
        mockedCommand "checkoutSubprojectDirectories $@"
    }

    requiredSubprojectsForBuild() {
        mockedCommand "requiredSubprojectsForBuild $@"
        echo "src-abc src-foo src-bar"
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


testCreateWorkspace_withoutProblems() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    assertTrue "createWorkspace"

    assertTrue "[[ -d ${WORKSPACE}/workspace/.build_workdir ]]"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustHaveValue LFS productName
switchSvnServerInLocations pronb-developer
mustHaveValue src-project src directory
latestRevisionFromRevisionStateFile 
mustHaveValue 12345 revision from revision state file
checkoutSubprojectDirectories src-project 12345
requiredSubprojectsForBuild 
mustHaveValue src-abc src-foo src-bar build targets
latestRevisionFromRevisionStateFile 
mustHaveValue 12345 revision from revision state file
checkoutSubprojectDirectories src-abc 12345
latestRevisionFromRevisionStateFile 
mustHaveValue 12345 revision from revision state file
checkoutSubprojectDirectories src-foo 12345
latestRevisionFromRevisionStateFile 
mustHaveValue 12345 revision from revision state file
checkoutSubprojectDirectories src-bar 12345
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"
}

testCreateWorkspace_parseErrorLocation() {
    export JOB_NAME=LFS_CI_-_
    export WORKSPACE=$(createTempDirectory)
    assertFalse "createWorkspace"
}
testCreateWorkspace_parseErrorTarget() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_
    export WORKSPACE=$(createTempDirectory)
    assertFalse "createWorkspace"
}

testCreateWorkspace_parseErrorProductName() {
    export JOB_NAME=ABC_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    assertFalse "createWorkspace"
}


source lib/shunit2

exit 0
