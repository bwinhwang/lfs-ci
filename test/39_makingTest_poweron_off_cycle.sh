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
    makingTest_testSuiteDirectory(){
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo /path/to/test/suite
    }
    mustHaveMakingTestTestConfig() {
        mockedCommand "mustHaveMakingTestTestConfig $@"
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
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

test1_poweron() {
    assertTrue "makingTest_poweron"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
mustExistDirectory /path/to/test/suite
execute make -C /path/to/test/suite powercycle
EOF
    assertExecutedCommands ${expect}

    return
}

test1_poweroff() {
    assertTrue "makingTest_poweroff"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
mustExistDirectory /path/to/test/suite
execute -i make -C /path/to/test/suite poweroff
EOF
    assertExecutedCommands ${expect}

    return
}

test1_powercycle() {
    assertTrue "makingTest_powercycle"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
mustExistDirectory /path/to/test/suite
execute make -C /path/to/test/suite powercycle
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
