#!/bin/bash

source test/common.sh
source lib/uc_release_share_build_artifacts.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            *) echo $1 ;;
        esac
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustBePreparedForReleaseTask() {
        mockedCommand "mustBePreparedForReleaseTask $@"
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-rfs-abc
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmpsl-abc
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmddal-abc
    }
    _synchronizeBuildResultsToShare() {
        mockedCommand "_synchronizeBuildResultsToShare $@"
    }
    getBuildBuildNumberFromFingerprint() {
        mockedCommand "getBuildBuildNumberFromFingerprint $@"
        echo Build_Job_Name
    }
    getBuildJobNameFromFingerprint() {
        mockedCommand "getBuildJobNameFromFingerprint $@"
        echo 12345
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)

    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_RELEASE_SHARE_BUILD_ARTIFACTS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
getBuildJobNameFromFingerprint 
getBuildBuildNumberFromFingerprint 
copyArtifactsToWorkspace 12345 Build_Job_Name
_synchronizeBuildResultsToShare bld-fsmddal-abc bld-fsmddal-abc/PS_LFS_OS_BUILD_NAME
_synchronizeBuildResultsToShare bld-fsmpsl-abc bld-fsmpsl-abc/PS_LFS_OS_BUILD_NAME
_synchronizeBuildResultsToShare bld-rfs-abc bld-rfs-abc/PS_LFS_OS_BUILD_NAME
execute rm -rf ${WORKSPACE}/workspace/bld
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
