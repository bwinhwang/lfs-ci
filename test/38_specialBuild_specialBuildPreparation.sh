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
    copyFileFromWorkspaceToBuildDirectory() {
        mockedCommand "copyFileFromWorkspaceToBuildDirectory $@"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        local wd=${WORKSPACE}/workspace/bld/bld-fsmci-summary
        mkdir -p ${wd}
        echo "LABEL" > ${wd}/label
        echo "LOCATION" > ${wd}/location
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }  

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}

    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_DEV_-_DEVELOPER_-_Build
    export BUILD_NUMBER=123

    export REQUESTOR="developer name"
    export REQUESTOR_FIRST_NAME="developer"
    export REQUESTOR_LAST_NAME="name"
    export REQUESTOR_EMAIL="developer.name@nokia.com"
    export REQUESTOR_USERID="dname"

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {

    assertTrue "specialBuildPreparation DEV LABEL REVISION LOCATION"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
copyFileFromWorkspaceToBuildDirectory LFS_DEV_-_DEVELOPER_-_Build 123 ${WORKSPACE}/revisionstate.xml
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-dev-input/
execute -i cp -a ${WORKSPACE}/lfs.patch ${WORKSPACE}/workspace/bld/bld-dev-input/
createArtifactArchive 
setBuildDescription LFS_DEV_-_DEVELOPER_-_Build 123 LABEL<br>developer name
EOF
    assertExecutedCommands ${expect}

    assertTrue "fsmci dir"     "[[ -d ${WORKSPACE}/workspace/bld/bld-fsmci-summary/ ]]"
    assertTrue "label"         "[[ -f ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label ]]"
    assertTrue "dev-input dir" "[[ -d ${WORKSPACE}/workspace/bld/bld-dev-input/ ]]"
    assertEquals "$(cat ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label)" \
                 "LABEL"

    return
}

source lib/shunit2

exit 0
