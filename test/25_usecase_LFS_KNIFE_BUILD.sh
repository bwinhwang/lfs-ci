#!/bin/bash

source test/common.sh

source lib/uc_knife_build.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        if [[ $1 = "mkdir" ]] ; then
            shift
            mkdir $@
        fi
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
    mustExistInSubversion() {
        mockedCommand "mustExistInSubversion $@"
    }
    svnCat() {
        mockedCommand "svnCat $@"
        echo "src-foo http://fake 12345"
    }
    createFingerprintFile() {
        mockedCommand "createFingerprintFile $@"
    }

}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    export REQUESTOR_FIRST_NAME="first"
    export REQUESTOR_LAST_NAME="name"
    export REQUESTOR_EMAIL="first.name@nokia.com"
    export REQUESTOR="knife requestor"
    export REQUESTOR_USERID="user"

    export KNIFE_LFS_BASELINE=PS_LFS_OS_2015_03_0001
    export BUILD_CAUSE_SCMTRIGGER=hand
}
tearDown() {
    true 
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build
    export BUILD_NUMBER=123

    assertTrue "usecase_LFS_KNIFE_BUILD"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustExistInSubversion https://ulscmi.inside.nsn.com/isource/svnroot/BTS_D_SC_LFS_2015_03/os/tags/PS_LFS_OS_2015_03_0001/doc/scripts/ revisions.txt
svnCat https://ulscmi.inside.nsn.com/isource/svnroot/BTS_D_SC_LFS_2015_03/os/tags/PS_LFS_OS_2015_03_0001/doc/scripts/revisions.txt
execute mkdir -p ${WORKSPACE}/workspace
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
createFingerprintFile 
copyFileFromWorkspaceToBuildDirectory LFS_KNIFE_-_knife_-_Build 123 ${WORKSPACE}/revisionstate.xml
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-knife-input/
execute -i cp -a ${WORKSPACE}/lfs.patch ${WORKSPACE}/workspace/bld/bld-knife-input/
createArtifactArchive 
setBuildDescription LFS_KNIFE_-_knife_-_Build 123 KNIFE_PS_LFS_OS_2015_03_0001.date<br>knife requestor
EOF
    assertExecutedCommands ${expect}

    assertTrue "[[ -d ${WORKSPACE}/workspace/bld/bld-fsmci-summary ]]"
    assertTrue "[[ -f ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label ]]"
    assertTrue "[[ -d ${WORKSPACE}/workspace/bld/bld-knife-input ]]"
    assertEquals "$(cat ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label)" "KNIFE_PS_LFS_OS_2015_03_0001.date"
    assertEquals "$(cat ${WORKSPACE}/revisionstate.xml)" \
                 "src-fake http://fakeurl/ 12345"

    return
}

source lib/shunit2

exit 0

