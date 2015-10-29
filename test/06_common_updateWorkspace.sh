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
    execute() {
        mockedCommand "execute $@"
        if [[ $2 == "build" && ! -z ${UT_BUILD_UPDATE_ALL_FAILED} ]] ; then
            mockedCommand "failed execute $@"
            return 1
        fi
    }
    setupNewWorkspace() {
        mkdir -p ${WORKSPACE}/workspace/.build_workdir
    }
    switchSvnServerInLocations() {
        mockedCommand "switchSvnServerInLocations $@"
    }
    latestRevisionFromRevisionStateFile() {
        mockedCommand "latestRevisionFromRevisionStateFile"
        echo 12345
    }
    checkoutSubprojectDirectories() {
        mockedCommand "checkoutSubprojectDirectories $@"
    }
    requiredSubprojectsForBuild() {
        mockedCommand "requiredSubprojectsForBuild $@"
        echo "src-abc src-foo src-bar"
    }
    createWorkspace() {
        mockedCommand "createWorkspace"
    }
    mustHaveLocalSdks() {
        mockedCommand "mustHaveLocalSdks"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    export UT_BUILD_UPDATE_ALL_FAILED=
    return
}

testUpdateWorkspace_withoutProblems() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    # assertTrue "updateWorkspace"
    assertTrue "updateWorkspace"
    assertTrue "[[ -d ${WORKSPACE}/workspace/.build_workdir ]]"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/revisions.txt
latestRevisionFromRevisionStateFile
execute --ignore-error build updateall -r 12345
mustHaveLocalSdks
copyAndExtractBuildArtifactsFromProject
EOF
    assertExecutedCommands ${expect}

    # TODO: demx2fk3 2014-11-24 add more tests here
}

testUpdateWorkspace_buildUpdateallFailed() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export UT_BUILD_UPDATE_ALL_FAILED=1
    export WORKSPACE=/tmp/${USER}/abc
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    assertTrue updateWorkspace
    assertTrue "[[ -d ${WORKSPACE}/workspace/.build_workdir ]]"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/revisions.txt
latestRevisionFromRevisionStateFile
execute --ignore-error build updateall -r 12345
failed execute --ignore-error build updateall -r 12345
createWorkspace
EOF
    assertExecutedCommands ${expect}

    # TODO: demx2fk3 2014-11-24 add more tests here
}

testUpdateWorkspace_parseErrorLocation() {
    export JOB_NAME=LFS_CI_-_
    assertFalse "updateWorkspace"
}
testUpdateWorkspace_parseErrorTarget() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_
    assertFalse "updateWorkspace"
}
testUpdateWorkspace_parseErrorProductName() {
    export JOB_NAME=ABC_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    assertFalse "updateWorkspace"
}


source lib/shunit2

exit 0
