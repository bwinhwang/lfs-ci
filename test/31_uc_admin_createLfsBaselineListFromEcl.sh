#!/bin/bash

source test/common.sh

source lib/uc_admin.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        sleep 4
    }
    createTempFile() {
        echo /path/to/tmp
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    assertTrue "createLfsBaselineListFromEcl"

    local expect=$(mktemp)
cat <<EOF > ${expect}
execute -n grep -e PS_LFS_OS -e PS_LFS_REL */ECL_BASE/ECL
execute -n cut -d= -f2
execute -n cat /path/to/tmp /path/to/tmp
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
