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
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
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
getConfig LFS_PROD_svn_delivery_os_repos_url -t tagName:PS_LFS_OS_2015_03_0001
mustExistInSubversion LFS_PROD_svn_delivery_os_repos_url/tags/PS_LFS_OS_2015_03_0001/doc/scripts/ revisions.txt
svnCat LFS_PROD_svn_delivery_os_repos_url/tags/PS_LFS_OS_2015_03_0001/doc/scripts/revisions.txt
getConfig LFS_PROD_tag_to_branch -t tagName:PS_LFS_OS_2015_03_0001
execute mkdir -p ${WORKSPACE}/workspace
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
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

