#!/bin/bash

source test/common.sh
source lib/uc_yaft_update_revision.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getWorkspaceName() {
        mockedCommand "getWorkspaceName $@"
        rm -rf ${WORKSPACE}/workspace/
        mkdir -p ${WORKSPACE}/workspace/
        echo ${WORKSPACE}/workspace
    }
    mustHaveWorkspaceName() {
        mockedCommand "mustHaveWorkspaceName $@"
    }
    execute() {
        mockedCommand "execute $@"
        # we want to create directories...
        if [[ $1 == mkdir ]] ; then 
            $@
        fi
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    svnCommit() {
        mockedCommand "svnCommit $@"
    }
    svnDiff() {
        mockedCommand "svnDiff $@"
    }
    mustExistInSubversion() {
        mockedCommand "mustExistInSubversion $@"
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace $@"
    }
    getSvnLastChangedRevision() {
        mockedCommand "getSvnLastChangedRevision $@"
        echo 1234
    }
    createBasicWorkspace() {
        mockedCommand "createBasicWorkspace $@"
        mkdir -p ${WORKSPACE}/workspace/src-project
        echo "hint foobar  1"               >> ${WORKSPACE}/workspace/src-project/Dependencies
        echo "hint src-foo 2"               >> ${WORKSPACE}/workspace/src-project/Dependencies
        echo "hint bld/yaft   --revision=2" >> ${WORKSPACE}/workspace/src-project/Dependencies
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_update_yaft_revision
    export BUILD_NUMBER=1234
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_YAFT_UPDATE_REVISION"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getWorkspaceName 
mustHaveWorkspaceName 
mustHaveCleanWorkspace 
mustExistInSubversion https://svne1.access.nsn.com/isource/svnroot/BTS_T_YAFT trunk
getSvnLastChangedRevision https://svne1.access.nsn.com/isource/svnroot/BTS_T_YAFT/trunk
createBasicWorkspace -l pronb-developer src-project
execute sed -i -e s|\(hint *bld/yaft *--revision\).*|\1=1234| ${WORKSPACE}/workspace/src-project/Dependencies
svnDiff ${WORKSPACE}/workspace/src-project/Dependencies
svnCommit -F ${WORKSPACE}/commitComment ${WORKSPACE}/workspace/src-project/Dependencies
setBuildDescription LFS_CI_-_trunk_-_update_yaft_revision 1234 yaft rev. 1234
EOF
    assertExecutedCommands ${expect}

    local expectFile=$(createTempFile)
cat <<EOF > ${expectFile}
hint foobar  1
hint src-foo 2
hint bld/yaft   --revision=2
EOF

    assertEquals "$(cat ${expectFile})" \
                 "$(cat ${WORKSPACE}/workspace/src-project/Dependencies)"

    return
}

source lib/shunit2

exit 0
