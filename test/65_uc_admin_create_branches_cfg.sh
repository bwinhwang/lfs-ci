#!/bin/bash

source test/common.sh

source lib/uc_admin_create_branches_cfg.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        for i in $(seq 1 ${UT_LINES_COUNT}) ; do
            echo "branches.cfg line $i"
        done
        if [[ $@ =~ cmp ]] ; then
            return ${UT_CMP}
        fi
    }
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_LINES_COUNT=200
    export UT_CMP=0
    assertTrue "usecase_ADMIN_CREATE_BRANCHES_CFG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n ${LFS_CI_ROOT}/bin/getBranchInformation
execute -i cmp ${WORKSPACE}/branches.cfg ${LFS_CI_ROOT}/etc/branches.cfg
EOF
    assertExecutedCommands ${expect}

    return
}


test2() {
    UT_LINES_COUNT=50
    export UT_CMP=0
    assertFalse "usecase_ADMIN_CREATE_BRANCHES_CFG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n ${LFS_CI_ROOT}/bin/getBranchInformation
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    UT_LINES_COUNT=200
    UT_CMP=1
    assertTrue "usecase_ADMIN_CREATE_BRANCHES_CFG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n ${LFS_CI_ROOT}/bin/getBranchInformation
execute -i cmp ${WORKSPACE}/branches.cfg ${LFS_CI_ROOT}/etc/branches.cfg
execute mv ${WORKSPACE}/branches.cfg ${LFS_CI_ROOT}/etc/branches.cfg
EOF
    assertExecutedCommands ${expect}

    return
}

test4() {
    UT_LINES_COUNT=50
    UT_CMP=1
    assertFalse "usecase_ADMIN_CREATE_BRANCHES_CFG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n ${LFS_CI_ROOT}/bin/getBranchInformation
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
