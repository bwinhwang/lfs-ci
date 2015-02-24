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
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
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
        mockedCommand "getBuildJobNameFromUpstreamProject $@"
        echo 1234
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
    export JOB_NAME=PKGPOOL_PROD_-_trunk_-_Release
    export BUILD_NUMBER=1234
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234

    mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
    echo LABEL > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/label
    echo OLD_LABEL > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/oldLabel

    assertTrue "ci_job_test"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace
getBuildJobNameFromUpstreamProject PKGPOOL_CI_-_trunk_-_Test 1234
getBuildJobNameFromUpstreamProject PKGPOOL_CI_-_trunk_-_Test 1234
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Build 1234 fsmci
copyFileFromBuildDirectoryToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 upstream
copyFileFromBuildDirectoryToWorkspace PKGPOOL_CI_-_trunk_-_Test 1234 properties
execute cp ${LFS_CI_ROOT}/etc/junit_dummytest.xml ${WORKSPACE}
setBuildDescription PKGPOOL_PROD_-_trunk_-_Release 1234 
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
