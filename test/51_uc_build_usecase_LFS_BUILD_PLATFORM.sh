#!/bin/bash

source test/common.sh
source lib/uc_build.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    execute() {
        mockedCommand "execute $@"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
    }
    mustHaveNextCiLabelName() {
        mockedCommand "mustHaveNextCiLabelName $@"
    }
    databaseEventSubBuildStarted() {
        mockedCommand "databaseEventSubBuildStarted $@"
    }
    createWorkspace() {
        mockedCommand "createWorkspace $@"
    }
    exit_add() {
        mockedCommand "exit_add $@"
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    buildLfs() {
        mockedCommand "buildLfs $@"
    }
    _build_fsmddal_pdf() {
        mockedCommand "_build_fsmddal_pdf $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    getNextCiLabelName() {
        mockedCommand "getNextCiLabelName $@"
        echo "build_name"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Build
    export UPSTREAM_BUILD=1234
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3_-_fsm3_octeon2
    export BUILD_NUMBER=1234
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_BUILD_PLATFORM"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 fsmci
mustHaveNextCiLabelName 
databaseEventSubBuildStarted 
exit_add _recordSubBuildEndEvent
getNextCiLabelName 
setBuildDescription ${JOB_NAME} 1234 build_name
execute rm -rf ${WORKSPACE}/revisions.txt
createWorkspace 
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 fsmci
mustHaveNextCiLabelName 
buildLfs 
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}


test2() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3-FSMDDALpdf_-_fsm3_octeon2
    assertTrue "usecase_LFS_BUILD_PLATFORM"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 fsmci
mustHaveNextCiLabelName 
databaseEventSubBuildStarted 
exit_add _recordSubBuildEndEvent
getNextCiLabelName 
setBuildDescription ${JOB_NAME} 1234 build_name
execute rm -rf ${WORKSPACE}/revisions.txt
createWorkspace 
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 fsmci
mustHaveNextCiLabelName 
_build_fsmddal_pdf 
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
