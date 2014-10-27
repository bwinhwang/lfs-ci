#!/bin/bash

export UNITTEST_TRUE_COMMAND=$(mktemp)
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
    assertTrue "execute mocked true Command" 'execute trueCommand'
    assertEquals 'mocked true command executed' 1 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}
testExecute_part2() {
    assertFalse "execute mocked false Command" 'execute falseCommand'
    assertEquals 'mocked false command executed' 1 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}
testExecute_part3() {
    assertFalse "execute mocked false Command" 'execute -r 3 falseCommand'
    assertEquals 'mocked false command executed' 3 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}
testExecute_part4() {
    assertTrue "execute mocked false Command" 'execute -n -r 3 trueCommand'
    assertEquals 'mocked false command executed' 1 "$(cat ${UNITTEST_TRUE_COMMAND} | wc -l)"
}


source lib/commands.sh
source lib/shunit2

exit 0
