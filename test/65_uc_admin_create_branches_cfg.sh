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
    UT_LINES_COUNT=200
    assertTrue "usecase_ADMIN_CREATE_BRANCHES_CFG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n ${LFS_CI_ROOT}/bin/getBranchesInformation
execute mv ${WORKSPACE}/branches.cfg ${LFS_CI_ROOT}/etc/branches.cfg
EOF
    assertExecutedCommands ${expect}

    return
}


test2() {
    UT_LINES_COUNT=50
    assertFalse "usecase_ADMIN_CREATE_BRANCHES_CFG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n ${LFS_CI_ROOT}/bin/getBranchesInformation
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
