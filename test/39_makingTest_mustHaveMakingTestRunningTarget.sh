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
        UT_MAKE_FAILS_COUNT=$((UT_MAKE_FAILS_COUNT - 1))
        return ${UT_MAKE_FAILS_COUNT}
    }
    mustHaveMakingTestTestConfig(){
        mockedCommand "mustHaveMakingTestTestConfig $@"
    }
    makingTest_testSuiteDirectory() {
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo ${WORKSPACE}/workspace/path/to/test/suite
    }
    getConfig() {
        echo ${UT_REBOOT_TRY}
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
    export UT_REBOOT_TRY=1
    export UT_MAKE_FAILS_COUNT=1 # means return 0
    assertTrue "mustHaveMakingTestRunningTarget"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite waitssh
execute sleep 0.0
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    # will reboot one additional time
    export UT_REBOOT_TRY=4
    export UT_MAKE_FAILS_COUNT=3  
    assertTrue "mustHaveMakingTestRunningTarget"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveMakingTestTestConfig 
makingTest_testSuiteDirectory 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite waitssh
execute make -C ${WORKSPACE}/workspace/path/to/test/suite powercycle
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite waitssh
execute sleep 60
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
