#!/bin/bash

source test/common.sh
source lib/subversion.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustExistBranchInSubversion() {
        mockedCommand "mustExistBranchInSubversion $@"
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
    assertTrue "mustExistSubversionDirectory https://svne1/BTS_SC_LFS os/branches/foobar/path"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustExistBranchInSubversion https://svne1/BTS_SC_LFS os
mustExistBranchInSubversion https://svne1/BTS_SC_LFS/os branches
mustExistBranchInSubversion https://svne1/BTS_SC_LFS/os/branches foobar
mustExistBranchInSubversion https://svne1/BTS_SC_LFS/os/branches/foobar path
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
