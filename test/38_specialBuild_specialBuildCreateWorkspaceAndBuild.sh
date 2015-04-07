#!/bin/bash

source test/common.sh

source lib/uc_developer_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        if [[ $1 = mkdir ]] ; then
            shift
            mkdir $@
        fi
    }
    createWorkspace() {
        mockedCommand "createWorkspace $@"
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
        local wd=${WORKSPACE}/workspace/bld/bld-fsmci-summary
        mkdir -p ${wd}
        echo "LABEL" > ${wd}/label
        echo "LOCATION" > ${wd}/location
    }
    applyKnifePatches() {
        mockedCommand "applyKnifePatches $@"
    }
    buildLfs() {
        mockedCommand "buildLfs $@"
    }  
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }  
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }  
    mustHaveLocationForSpecialBuild() {
        mockedCommand "mustHaveLocationForSpecialBuild $@"
        export LFS_CI_GLOBAL_BRANCH_NAME=LOCATION
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}

    export WORKSPACE=$(createTempDirectory)

    export JOB_NAME=LFS_DEV_-_DEVELOPER_-_Build_-_FSM-r2_-_fcmd
    export BUILD_NUMBER=123
    export UPSTREAM_PROJECT=LFS_DEV_-_DEVELOPER_-_Build
    export UPSTREAM_BUILD=987

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {

    assertTrue "specialBuildCreateWorkspaceAndBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveLocationForSpecialBuild 
execute rm -rf ${WORKSPACE}/revisions.txt
createWorkspace 
copyArtifactsToWorkspace LFS_DEV_-_DEVELOPER_-_Build 987 fsmci
setBuildDescription LFS_DEV_-_DEVELOPER_-_Build_-_FSM-r2_-_fcmd 123 LABEL
applyKnifePatches 
buildLfs 
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
