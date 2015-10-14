#!/bin/bash

source test/common.sh
source lib/logging.sh
setUp() {
    ###export CI_LOGGING_LOGFILENAME=$(createTempFile)
    export CI_LOGGING_LOGFILENAME_COMPLETE=$(createTempFile)
}
tearDown() {
    rm -rf ${CI_LOGGING_LOGFILENAME_COMPLETE}
    ###rm -rf ${CI_LOGGING_LOGFILENAME}
}

test1() {
    message FOOBAR TEST_MESSAGE
    assertEquals "didn't find test message in complete log" \
        "1" \
        $(grep -c TEST_MESSAGE ${CI_LOGGING_LOGFILENAME_COMPLETE})

    ###assertEquals "didn't find test message in short log" \
    ###    "0" \
    ###    $(grep -c TEST_MESSAGE ${CI_LOGGING_LOGFILENAME})
}

test2() {
    message TRACE TEST_MESSAGE
    assertEquals "didn't find test message in complete log" \
        "1" \
        $(grep -c TEST_MESSAGE ${CI_LOGGING_LOGFILENAME_COMPLETE})

    ###assertEquals "didn't find test message in short log" \
    ###    "1" \
    ###    $(grep -c TEST_MESSAGE ${CI_LOGGING_LOGFILENAME})

}

source lib/shunit2

exit 0
