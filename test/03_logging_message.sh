#!/bin/bash

export UT_MOCKED_COMMANDS=$(mktemp)

## @fn      assertExecutedCommands()
#  @brief   check for the executed commands in unit test
#  @param   {expect}    file with expected commands
#  @return  <none>
assertExecutedCommands() {
    local expect=$1

    diff -u ${expect} ${UT_MOCKED_COMMANDS}
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/logging.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    startLogfile() {
        mockedCommand "startLogfile $@"
    }
    _loggingLine() {
        mockedCommand "_loggingLine $@"
        echo "LOG LINE: $@"
    }
    shouldWriteLogMessageToFile() {
        mockedCommand "shouldWriteLogMessageToFile $@"
        return ${UT_SHOULD_WRITE_LOG}
    }
    return
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export CI_LOGGING_LOGFILENAME_COMPLETE=$(mktemp)
    ###export CI_LOGGING_LOGFILENAME=$(mktemp)
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    ###rm -rf ${CI_LOGGING_LOGFILENAME}
    rm -rf ${CI_LOGGING_LOGFILENAME_COMPLETE}
    return
}

test1_info() {
    assertTrue "log function not ok" "message INFO test"

    local expect=$(mktemp)
    cat <<EOF > ${expect}
startLogfile 
_loggingLine INFO PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test
shouldWriteLogMessageToFile INFO
_loggingLine INFO PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test
_loggingLine INFO PREFIX DATE SPACE DURATION SPACE TYPE MESSAGE test
EOF
    assertExecutedCommands ${expect}
    rm -rf ${expect}

    assertEquals "complete logfile not ok" \
        "$(cat ${CI_LOGGING_LOGFILENAME_COMPLETE})" \
        "LOG LINE: INFO PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test" 
    ###assertEquals "short logfile not ok" \
    ###    "$(cat ${CI_LOGGING_LOGFILENAME})" \
    ###    "LOG LINE: INFO PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test" 

    return
}

test2_info() {
    export UT_SHOULD_WRITE_LOG=1

    assertTrue "log function not ok" "message INFO test"

    local expect=$(mktemp)
    cat <<EOF > ${expect}
startLogfile 
_loggingLine INFO PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test
shouldWriteLogMessageToFile INFO
EOF
    assertExecutedCommands ${expect}
    rm -rf ${expect}

    assertEquals "complete logfile not ok" \
        "$(cat ${CI_LOGGING_LOGFILENAME_COMPLETE})" \
        "LOG LINE: INFO PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test" 
    ###assertEquals "short logfile not ok" \
    ###    "$(cat ${CI_LOGGING_LOGFILENAME})" \
    ###    "" 

    return
}

test3_trace() {
    export UT_SHOULD_WRITE_LOG=0

    assertTrue "log function not ok" "message TRACE test"

    local expect=$(mktemp)
    cat <<EOF > ${expect}
startLogfile 
_loggingLine TRACE PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test
shouldWriteLogMessageToFile TRACE
_loggingLine TRACE PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test
EOF
    assertExecutedCommands ${expect}
    rm -rf ${expect}

    assertEquals "complete logfile not ok" \
        "$(cat ${CI_LOGGING_LOGFILENAME_COMPLETE})" \
        "LOG LINE: TRACE PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test" 
    ###assertEquals "short logfile not ok" \
    ###    "$(cat ${CI_LOGGING_LOGFILENAME})" \
    ###    "LOG LINE: TRACE PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test" 

    return
}

test4_debug() {
    export UT_SHOULD_WRITE_LOG=0

    assertTrue "log function not ok" "message DEBUG test"

    local expect=$(mktemp)
    cat <<EOF > ${expect}
startLogfile 
_loggingLine DEBUG PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test
shouldWriteLogMessageToFile DEBUG
_loggingLine DEBUG PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test
EOF
    assertExecutedCommands ${expect}
    rm -rf ${expect}

    assertEquals "complete logfile not ok" \
        "$(cat ${CI_LOGGING_LOGFILENAME_COMPLETE})" \
        "LOG LINE: DEBUG PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test" 
    ###assertEquals "short logfile not ok" \
    ###    "$(cat ${CI_LOGGING_LOGFILENAME})" \
    ###    "LOG LINE: DEBUG PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER test" 

    return
}
source lib/shunit2

exit 0
