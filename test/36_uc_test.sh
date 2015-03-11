#!/bin/bash

source test/common.sh

source lib/uc_test.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace"
        mkdir -p ${WORKSPACE}/workspace
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    execute() {
        mockedCommand "execute $@"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyArtifactsToWorkspace $@"
        if [[ ${UT_NO_ARTIFACTS} ]] ; then
            mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary
            echo PS_LFS_OS_2015_02_1234 > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
        fi
    }
    mustBeValidXmlReleaseNote() {
        mockedCommand "mustBeValidXmlReleaseNote $@"
    }
    uploadToWorkflowTool() {
        mockedCommand "uploadToWorkflowTool $@"
    }
    createReleaseInWorkflowTool() {
        mockedCommand "createReleaseInWorkflowTool $@"
    }
    linkFileToArtifactsDirectory() {
        mockedCommand "linkFileToArtifactsDirectory $@"
    }
    copyFileFromBuildDirectoryToWorkspace() {
        mockedCommand "copyFileFromBuildDirectoryToWorkspace $@"
    }
    copyFileToArtifactDirectory() {
        mockedCommand "copyFileToArtifactDirectory $@"
    }
    runOnMaster() {
        mockedCommand "runOnMaster $@"
        return 0
    }
    copyFileFromWorkspaceToBuildDirectory() {
        mockedCommand "copyFileFromWorkspaceToBuildDirectory $@"
    }
    exit_add() {
        mockedCommand "exit_add $@"
    }
    databaseEventTestStarted() {
        mockedCommand "databaseEventTestStarted $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    copyFileFromBuildDirectoryToWorkspace() {
        mockedCommand "copyFileFromBuildDirectoryToWorkspace $@"
        touch ${WORKSPACE}/$3
    }
    getBuildJobNameFromUpstreamProject() {
        mockedCommand "getBuildJobNameFromUpstreamProject $@"
        echo LFS_CI_-_trunk_-_Build
    }
    getBuildBuildNumberFromUpstreamProject() {
        mockedCommand "getBuildBuildNumberFromUpstreamProject $@"
        echo 1234
    }
    getConfig() {
        case $1 in 
            LFS_CI_UC_package_internal_link)      echo ${UT_ARTIFACTS_SHARE} ;;
            LFS_CI_UC_package_copy_to_share_name) echo ${UT_ARTIFACTS_SHARE} ;;
            LFS_CI_UC_test_required_artifacts)    echo fsmci                 ;;
        esac
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Test
    export BUILD_NUMBER=1234
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Package_-_package
    export UPSTREAM_BUILD=1234
    export UT_NO_ARTIFACTS=

    export UT_ARTIFACTS_SHARE=$(createTempDirectory)
    mkdir -p ${UT_ARTIFACTS_SHARE}/PS_LFS_OS_2015_02_1234
    cd ${UT_ARTIFACTS_SHARE} 
    ln -sf PS_LFS_OS_2015_02_1234 build_1234
    cd - 1>/dev/null

    assertTrue "ci_job_test"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Package_-_package 1234 fsmci
databaseEventTestStarted 
exit_add _exitHandlerDatabaseTestFailed
copyFileFromWorkspaceToBuildDirectory LFS_CI_-_trunk_-_Test 1234 ${WORKSPACE}/workspace/upstream
copyFileFromWorkspaceToBuildDirectory LFS_CI_-_trunk_-_Test 1234 ${WORKSPACE}/workspace/properties
setBuildDescription LFS_CI_-_trunk_-_Test 1234 PS_LFS_OS_2015_02_1234
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Test
    export BUILD_NUMBER=1234
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Package_-_package
    export UPSTREAM_BUILD=1234
    export UT_NO_ARTIFACTS=1

    export UT_ARTIFACTS_SHARE=$(createTempDirectory)
    mkdir -p ${UT_ARTIFACTS_SHARE}/PS_LFS_OS_2015_02_1234
    cd ${UT_ARTIFACTS_SHARE} 
    ln -sf PS_LFS_OS_2015_02_1234 build_1234
    cd - 1>/dev/null

    assertTrue "ci_job_test"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Package_-_package 1234 fsmci
databaseEventTestStarted 
exit_add _exitHandlerDatabaseTestFailed
copyFileFromWorkspaceToBuildDirectory LFS_CI_-_trunk_-_Test 1234 ${WORKSPACE}/workspace/upstream
copyFileFromWorkspaceToBuildDirectory LFS_CI_-_trunk_-_Test 1234 ${WORKSPACE}/workspace/properties
setBuildDescription LFS_CI_-_trunk_-_Test 1234 PS_LFS_OS_2015_02_1234
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Test_-_FSM-r3_-_Test_on_Target
    export BUILD_NUMBER=1234
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234

    export UT_ARTIFACTS_SHARE=$(createTempDirectory)
    mkdir -p ${UT_ARTIFACTS_SHARE}/PS_LFS_OS_2015_02_1234
    cd ${UT_ARTIFACTS_SHARE} 
    ln -sf PS_LFS_OS_2015_02_1234 build_1234
    cd - 1>/dev/null

    assertTrue "ci_job_test"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Test 1234 fsmci
copyFileFromBuildDirectoryToWorkspace LFS_CI_-_trunk_-_Test 1234 properties
copyFileFromBuildDirectoryToWorkspace LFS_CI_-_trunk_-_Test 1234 upstream
setBuildDescription LFS_CI_-_trunk_-_Test_-_FSM-r3_-_Test_on_Target 1234 PS_LFS_OS_2015_02_1234
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}
    return
}

source lib/shunit2

exit 0
