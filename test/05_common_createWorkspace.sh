#!/bin/bash

source test/common.sh

source lib/createWorkspace.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
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
    switchToNewLocation() {
        mockedCommand "switchToNewLocation $@"
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
    mustHaveLocalSdks() {
        mockedCommand "mustHaveLocalSdks $@"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
    }
    getLocationName() {
        echo pronb-developer
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
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
latestRevisionFromRevisionStateFile 
switchToNewLocation pronb-developer
switchSvnServerInLocations pronb-developer
checkoutSubprojectDirectories src-project 12345
requiredSubprojectsForBuild 
latestRevisionFromRevisionStateFile 
checkoutSubprojectDirectories src-abc 12345
latestRevisionFromRevisionStateFile 
checkoutSubprojectDirectories src-foo 12345
latestRevisionFromRevisionStateFile 
checkoutSubprojectDirectories src-bar 12345
mustHaveLocalSdks 
copyAndExtractBuildArtifactsFromProject 
EOF

    assertExecutedCommands ${expect}
}

source lib/shunit2

exit 0
