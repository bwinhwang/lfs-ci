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
    _reserveTarget(){
        mockedCommand "_reserveTarget $@"
        echo "TargetName"
    }
    makingTest_testSuiteDirectory(){
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo /path/to/test/suite
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
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
    assertTrue "makingTest_testconfig"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_reserveTarget 
makingTest_testSuiteDirectory 
mustExistDirectory /path/to/test/suite
execute make -C /path/to/test/suite testconfig-overwrite TESTBUILD=${DELIVERY_DIRECTORY} TESTTARGET=targetname
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
