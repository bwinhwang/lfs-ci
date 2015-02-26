#!/bin/bash

source test/common.sh

source lib/uc_knife_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    createWorkspace() {
        mockedCommand "createWorkspace $@"
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
    }
    mustHaveNextCiLabelName() {
        true
    }
    getNextCiLabelName() {
        echo "PS_LFS_OS_NEXT"
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    buildLfs() {
        mockedCommand "buildLfs $@"
    }
    applyKnifePatches() {
        mockedCommand "applyKnifePatches $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    mustExistInSubversion() {
        mockedCommand "mustExistInSubversion $@"
    }
    svnCat() {
        mockedCommand "svnCat $@"
        echo "src-abc http://abc 12345"
    }


}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
}

tearDown() {
    true 
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd
    export BUILD_NUMBER=123
    export KNIFE_LFS_BASELINE=PS_LFS_OS_2015_01_0001

    assertTrue "usecase_LFS_KNIFE_BUILD_PLATFORM"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustExistInSubversion https://ulscmi.inside.nsn.com/isource/svnroot/BTS_D_SC_LFS_2015_01/os/tags/PS_LFS_OS_2015_01_0001/doc/scripts/ revisions.txt
svnCat https://ulscmi.inside.nsn.com/isource/svnroot/BTS_D_SC_LFS_2015_01/os/tags/PS_LFS_OS_2015_01_0001/doc/scripts/revisions.txt
createWorkspace 
copyArtifactsToWorkspace upstream_project 123 fsmci
setBuildDescription LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd 123 PS_LFS_OS_NEXT
applyKnifePatches 
buildLfs 
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export WORKSPACE=$(createTempDirectory)
    export KNIFE_LFS_BASELINE=PS_LFS_OS_INVALID
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd

    assertFalse "usecase_LFS_KNIFE_BUILD_PLATFORM"

    return
}

test3() {
    export WORKSPACE=$(createTempDirectory)
    export KNIFE_LFS_BASELINE=LRC_LCP_PS_LFS_OS_2015_01_0001
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build_-_FSM-r2_-_fcmd
    export BUILD_NUMBER=123

    assertTrue "usecase_LFS_KNIFE_BUILD_PLATFORM"

    return
}

source lib/shunit2

exit 0

