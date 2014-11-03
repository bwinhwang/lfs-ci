#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/commands.sh

export UNITTEST_TRUE_COMMAND=$(createTempFile)
# mock the date command
oneTimeSetUp() {
    mockedCommand() {
        echo command
    }
    exit_handler() {
        echo exit
    }
    falseCommand() {
        echo executed $@ >> ${UNITTEST_TRUE_COMMAND}
        return 1
    }
    trueCommand() {
        echo executed $@ >> ${UNITTEST_TRUE_COMMAND}
        return
    }
    export UNITTEST_TRUE_COMMAND_SUCCESS_THIRD=0
    successInThirdCommand() {
        UNITTEST_TRUE_COMMAND_SUCCESS_THIRD=$(( UNITTEST_TRUE_COMMAND_SUCCESS_THIRD + 1))
        if [[ ${UNITTEST_TRUE_COMMAND_SUCCESS_THIRD} -eq 3 ]] ; then
            return
        else
            return 1                 
        fi
    }
    sleep() {
        echo $@
    }
    return
}

setUp() {
    cp -f /dev/null ${UNITTEST_TRUE_COMMAND}
}

tearDown() {
    rm -rf ${UNITTEST_TRUE_COMMAND}
    return
}


testExecute_part1() {
    assertTrue "execute trueCommand part1"
    assertEquals 'mocked true command executed' 1 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}
testExecute_part2() {
    assertFalse 'execute falseCommand part2'
    assertEquals 'mocked false command executed' 1 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}
testExecute_part3() {
    assertFalse 'execute -r 3 falseCommand part3'
    assertEquals 'mocked false command executed' 3 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}
testExecute_part4() {
    assertTrue 'execute -n -r 3 trueCommand part4'
    assertEquals 'mocked false command executed' 1 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}
testExecute_part5() {
    assertTrue 'execute -n -r 3 successInThirdCommand part5'
}


source lib/shunit2

exit 0
