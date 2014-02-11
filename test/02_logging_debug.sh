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
                 "mocked date command     [DEBUG] foobar" \
                 "`debug 'foobar'`" 

    local veryLongDebugMessage="this is a very long info message for the logging function in the logging method. this should work without any problem"
    assertEquals "longer debug message"                                   \
                 "mocked date command     [DEBUG] ${veryLongDebugMessage}" \
                 "`debug \"${veryLongDebugMessage}\"`" 


    assertEquals "simple info message"                   \
                 "mocked date command      [INFO] foobar" \
                 "`info 'foobar'`" 

    assertEquals "longer info message"                                    \
                 "mocked date command      [INFO] ${veryLongDebugMessage}" \
                 "`info \"${veryLongDebugMessage}\"`" 


    assertEquals "simple warning message"                \
                 "mocked date command   [WARNING] foobar" \
                 "`warning 'foobar'`" 

    assertEquals "longer warning message"                                 \
                 "mocked date command   [WARNING] ${veryLongDebugMessage}" \
                 "`warning \"${veryLongDebugMessage}\"`" 


    assertEquals "simple error message"                  \
                 "mocked date command     [ERROR] foobar" \
                 "`error 'foobar'`" 

    assertEquals "longer error message"                                   \
                 "mocked date command     [ERROR] ${veryLongDebugMessage}" \
                 "`error \"${veryLongDebugMessage}\"`" 
}

testLoggingConfiguration() {

    export CI_LOGGING_CONFIG="MESSAGE"
    assertEquals "simple message with configuration"  \
                 "foobar"                             \
                 "`message INFO 'foobar'`" 

    export CI_LOGGING_CONFIG="DATE MESSAGE"
    assertEquals "simple message with configuration"  \
                 "mocked date command foobar"         \
                 "`message INFO 'foobar'`" 

    export CI_LOGGING_CONFIG="TYPE"
    assertEquals "simple message with configuration"  \
                 "    [INFO]"                         \
                 "`message INFO 'foobar'`" 

    export CI_LOGGING_CONFIG="CALLER"
    assertEquals "simple message with configuration"  \
                 "called from Method '_shunit_execSuite' in File lib/shunit2, Line 786" \
                 "`message INFO 'foobar'`" 

    export CI_LOGGING_PREFIX="global prefix"
    export CI_LOGGING_CONFIG="PREFIX"
    assertEquals "simple message with configuration"  \
                 "global prefix"                      \
                 "`message INFO 'foobar'`" 
    unset CI_LOGGING_PREFIX CI_LOGGING_CONFIG


    declare -A CI_LOGGING_PREFIX_HASH=( ["INFO"]="info prefix" )
    export CI_LOGGING_CONFIG="PREFIX"
    assertEquals "no output without config"  \
                 "info prefix"               \
                 "`message INFO 'foobar'`" 

    assertEquals "no output without config"  \
                 ""                          \
                 "`message DEBUG 'foobar'`" 

    declare -A CI_LOGGING_PREFIX_HASH=( ["INFO"]="info prefix"  \
                                        ['ERROR']='error prefix' )
    assertEquals "no output without config"  \
                 "info prefix"               \
                 "`message INFO 'foobar'`" 

    assertEquals "no output without config"  \
                 "error prefix"              \
                 "`message ERROR 'foobar'`" 

    assertEquals "no output without config"  \
                 ""                          \
                 "`message DEBUG 'foobar'`" 
}

testLoggingConfigurationColors() {

    export CI_LOGGING_ENABLE_COLORS=1
    declare -A CI_LOGGING_COLOR_HASH=( ["INFO"]="CYAN"  \
                                       ['ERROR']='RED' )

    export CI_LOGGING_CONFIG="TYPE SPACE MESSAGE"
    WHITE="\033[37m"
    CYAN="\033[36m"
    RED="\033[31m"
    assertEquals "" \
                 "$(echo -ne ${CYAN}'    '[INFO] foobar${WHITE})" \
                 "`message INFO 'foobar'`" 

    assertEquals "no output without config"  \
                 "$(echo -ne ${RED}'   '[ERROR] foobar${WHITE})" \
                 "`message ERROR 'foobar'`" 

    assertEquals "no output without config"  \
                 "   [DEBUG] foobar"         \
                 "`message DEBUG 'foobar'`" 
}

source lib/shunit2

exit 0
