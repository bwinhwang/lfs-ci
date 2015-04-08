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
    makingTest_testSuiteDirectory() {
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo ${WORKSPACE}/workspace/path/to/test/suite
    }
    makingTest_testconfig() {
        mockedCommand "makingTest_testconfig $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export DELIVERY_DIRECTORY=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/path/to/test/suite
    touch ${WORKSPACE}/workspace/path/to/test/suite/testconfig.mk

    mustHaveMakingTestTestConfig
    #assertTrue "mustHaveMakingTestTestConfig"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    rm -rf ${WORKSPACE}
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/path/to/test/suite

    mustHaveMakingTestTestConfig
    # assertTrue "mustHaveMakingTestTestConfig"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
makingTest_testconfig 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
