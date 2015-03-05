#!/bin/bash

source test/common.sh

source lib/makingtest.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustHaveMakingTestTestConfig(){
        mockedCommand "mustHaveMakingTestTestConfig $@"
    }
    makingTest_testSuiteDirectory() {
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo ${WORKSPACE}/workspace/path/to/test/suite
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/path/to/test/suite
    touch ${WORKSPACE}/workspace/path/to/test/suite/testsuite.mk
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "mustHaveMakingTestRunningTarget"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite waitprompt
execute make -C ${WORKSPACE}/workspace/path/to/test/suite waitssh
execute sleep 60
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
