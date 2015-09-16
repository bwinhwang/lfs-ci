#!/bin/bash

source test/common.sh
source lib/uc_test_on_target.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export DELIVERY_DIRECTORY=$(createTempDirectory)
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "testSandboxDummy"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/xml-reports/
execute cp ${LFS_CI_ROOT}/test/junitResult.xml ${WORKSPACE}/workspace/xml-reports/
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
