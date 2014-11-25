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
    mustHaveValue() {
        mockedCommand "mustHaveValue $@"
        return
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
    cp -f /dev/null ${UNITTEST_COMMAND}
}

tearDown() {
    rm -rf ${UNITTEST_COMMAND}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    export UT_BUILD_UPDATE_ALL_FAILED=
    return
}

testUpdateWorkspace_withoutProblems() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    # assertTrue "updateWorkspace"
    assertTrue "updateWorkspace"
    assertTrue "[[ -d ${WORKSPACE}/workspace/.build_workdir ]]"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/revisions.txt
latestRevisionFromRevisionStateFile
mustHaveValue 12345 revision from revision state file
execute --ignore-error build -W "${WORKSPACE}/workspace" --revision=12345 updateall
mustHaveLocalSdks
copyAndExtractBuildArtifactsFromProject
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

    # TODO: demx2fk3 2014-11-24 add more tests here
}

testUpdateWorkspace_buildUpdateallFailed() {

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    export UT_BUILD_UPDATE_ALL_FAILED=1
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    assertTrue updateWorkspace
    assertTrue "[[ -d ${WORKSPACE}/workspace/.build_workdir ]]"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/revisions.txt
latestRevisionFromRevisionStateFile
mustHaveValue 12345 revision from revision state file
execute --ignore-error build -W "${WORKSPACE}/workspace" --revision=12345 updateall
failed execute --ignore-error build -W "${WORKSPACE}/workspace" --revision=12345 updateall
createWorkspace
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

    # TODO: demx2fk3 2014-11-24 add more tests here
}

testUpdateWorkspace_parseErrorLocation() {
    export JOB_NAME=LFS_CI_-_
    export WORKSPACE=$(createTempDirectory)
    assertFalse "updateWorkspace"
}
testUpdateWorkspace_parseErrorTarget() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_
    export WORKSPACE=$(createTempDirectory)
    assertFalse "updateWorkspace"
}
testUpdateWorkspace_parseErrorProductName() {
    export JOB_NAME=ABC_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export WORKSPACE=$(createTempDirectory)
    assertFalse "updateWorkspace"
}


source lib/shunit2

exit 0
