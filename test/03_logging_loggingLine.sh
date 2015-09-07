#!/bin/bash

source lib/logging.sh

oneTimeSetUp() {
    bc() {
        echo "0.002"
    }
    date() {
        echo $1
    }
    return
}

setUp() {
    export CI_LOGGING_LOGFILENAME_COMPLETE=$(mktemp)
    export CI_LOGGING_LOGFILENAME=$(mktemp)
}

tearDown() {
    rm -rf ${CI_LOGGING_LOGFILENAME}
    rm -rf ${CI_LOGGING_LOGFILENAME_COMPLETE}
    return
}

test1_LINE() {
    local line="$(_loggingLine INFO LINE 'mes sage')"
    assertEquals \
        "-----------------------------------------------------------------" \
        "${line}"
    return
}

test2_SPACE() {
    local line="$(_loggingLine INFO SPACE 'mes sage')"
    assertEquals " " "${line}"
    return
}

test3_NEWLINE() {
    local line="$(_loggingLine INFO NEWLINE 'mes sage')"
    assertEquals "\n" "${line}"
    return
}

 test4_TAB() {
    local line="$(_loggingLine INFO TAB 'mes sage')"
    # TODO: demx2fk3 2015-08-25 does not work..
    # assertEquals "      " "${line}"
    return
}

test5_PREFIX() {
    export CI_LOGGING_PREFIX=prefix_123
    local line="$(_loggingLine INFO PREFIX 'mes sage')"
    assertEquals "prefix_123" "${line}"
    return
}

test6_DATE_SHORT() {
    local expected="$(date "+%Y-%m-%d %H:%M:%S")"

    local line="$(_loggingLine INFO DATE_SHORT 'mes sage')"
    assertEquals "${expected}" "${line}"
    return
}

test7_TYPE() {
    local line="$(_loggingLine INFO TYPE 'mes sage')"
    assertEquals "[INFO]    " "${line}"
    return
}

test8_DURATION() {
    export CI_LOGGING_DURATION_START_DATE=$(date +%s.%N)
    local line="$(_loggingLine INFO DURATION 'mes sage')"
    assertEquals '[    0.002]' "${line}"
    return
}

test9_NONE() {
    local line="$(_loggingLine INFO NONE 'mes sage')"
    assertEquals "" "${line}"
    return
}

test10_MESSAGE() {
    local line="$(_loggingLine INFO MESSAGE 'mes sage')"
    assertEquals "mes sage" "${line}"
    return
}

test11_CALLER() {
    local line="$(_loggingLine INFO CALLER 'mes sage')"
    assertEquals "lib/shunit2:source#110" "${line}"
    return
}

# test12_STACKTRACE() {
#     local line="$(_loggingLine INFO STACKTRACE 'mes sage')"
#     assertEquals "[INFO]" "${line}"
#     return
# }

test13_OTHER() {
    local line="$(_loggingLine INFO foobar 'mes sage')"
    assertEquals "foobar" "${line}"
    return
}
source lib/shunit2

exit 0
