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
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
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
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace $@"
    }
    mustHaveLocationForSpecialBuild() {
        mockedCommand "mustHaveLocationForSpecialBuild $@"
        export LFS_CI_GLOBAL_LOCATION_NAME=LOCATION

        local wd=${WORKSPACE}/workspace/bld/bld-dev-input/
        mkdir -p ${wd}
        echo "LFS_BUILD_FSMR2=true" > ${wd}/lfs_build.txt
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

    assertTrue "specialBuildCreateWorkspaceAndBuild DEV"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
copyArtifactsToWorkspace LFS_DEV_-_DEVELOPER_-_Build 987
mustHaveLocationForSpecialBuild 
execute rm -rf ${WORKSPACE}/revisions.txt
createWorkspace 
copyArtifactsToWorkspace LFS_DEV_-_DEVELOPER_-_Build 987
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
