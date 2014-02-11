#!/bin/bash


source lib/ci_logging.sh


# mock the date command
oneTimeSetUp() {

    date() {
        echo "mocked date command"
    }
}

testLogging() {

    assertEquals "simple debug message"                  \
                 "mocked date command    [debug] foobar" \
                 "`debug 'foobar'`" 

    local veryLongDebugMessage="this is a very long info message for the logging function in the logging method. this should work without any problem"
    assertEquals "longer debug message"                                   \
                 "mocked date command    [debug] ${veryLongDebugMessage}" \
                 "`debug \"${veryLongDebugMessage}\"`" 


    assertEquals "simple info message"                   \
                 "mocked date command     [info] foobar" \
                 "`info 'foobar'`" 

    assertEquals "longer info message"                                    \
                 "mocked date command     [info] ${veryLongDebugMessage}" \
                 "`info \"${veryLongDebugMessage}\"`" 


    assertEquals "simple warning message"                \
                 "mocked date command  [warning] foobar" \
                 "`warning 'foobar'`" 

    assertEquals "longer warning message"                                 \
                 "mocked date command  [warning] ${veryLongDebugMessage}" \
                 "`warning \"${veryLongDebugMessage}\"`" 


    assertEquals "simple error message"                  \
                 "mocked date command    [error] foobar" \
                 "`error 'foobar'`" 

    assertEquals "longer error message"                                   \
                 "mocked date command    [error] ${veryLongDebugMessage}" \
                 "`error \"${veryLongDebugMessage}\"`" 
}

source lib/shunit2

exit 0
