#!/bin/bash

source lib/common.sh

initTempDirectory

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
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    copyFileFromWorkspaceToBuildDirectory() {
        mockedCommand "copyFileFromWorkspaceToBuildDirectory $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    date() {
        echo date
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
    export KNIFE_LFS_BASELINE=PS_LFS_OS_2014_01_0001
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build
    export KNIFE_REQUESTOR="knife requestor"

    assertTrue "usecase_LFS_KNIFE_BUILD"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
copyFileFromWorkspaceToBuildDirectory LFS_KNIFE_-_knife_-_Build revisionstate.xml
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-knife-input/
execute -i cp -a ${WORKSPACE}/lfs.patch ${WORKSPACE}/workspace/bld/bld-knife-input/
createArtifactArchive 
setBuildDescription LFS_KNIFE_-_knife_-_Build  KNIFE_PS_LFS_OS_2014_01_0001.date<br>knife requestor
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/shunit2

exit 0

