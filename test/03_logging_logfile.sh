#!/bin/bash


source lib/logging.sh


# mock the date command
oneTimeSetUp() {

    date() {
        echo "mocked date command"
    }

}

tearDown() {
    [[ -f "${CI_LOGGING_LOGFILENAME}" ]] && rm -rf "${CI_LOGGING_LOGFILENAME}"
}

testStartLogfile_normal_startup() {

    unset CI_LOGGING_LOGFILENAME
    startLogfile

    assertNotNull "CI_LOGGING_LOGFILENAME is not null" "${CI_LOGGING_LOGFILENAME}"

    assertTrue "CI_LOGGING_LOGFILENAME is writable" '[ -w "${CI_LOGGING_LOGFILENAME}" ]'

    assertEquals "got correct logfile" \
                 "`cat test/data/03_test1.txt`" \
                 "`cat ${CI_LOGGING_LOGFILENAME}`"
}

testStartLogfile_file_not_writable() {

    # this create a new logfile
    local tmp=`mktemp`
    export CI_LOGGING_LOGFILENAME=${tmp}
    chmod 444  ${CI_LOGGING_LOGFILENAME}

    startLogfile

    assertNotNull "CI_LOGGING_LOGFILENAME is not null" "${CI_LOGGING_LOGFILENAME}"

    assertTrue "CI_LOGGING_LOGFILENAME is writable" '[ -w "${CI_LOGGING_LOGFILENAME}" ]'

    assertEquals "not writable file"  \
                 "`cat test/data/03_test1.txt`" \
                 "`cat ${CI_LOGGING_LOGFILENAME}`"

    rm -rf ${tmp}
}

testStartLogfile_file_is_writable() {

    # this create a new logfile
    local tmp=`mktemp`
    export CI_LOGGING_LOGFILENAME=${tmp}

    startLogfile

    assertNotNull "CI_LOGGING_LOGFILENAME is not null" "${CI_LOGGING_LOGFILENAME}"

    assertTrue "CI_LOGGING_LOGFILENAME is writable" '[ -w "${CI_LOGGING_LOGFILENAME}" ]'

    assertEquals "file is writable, no new file"  \
                 "" \
                 "`cat ${CI_LOGGING_LOGFILENAME}`"

    rm -rf ${tmp}
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

testStopLogfile_normal_shutdown() {

    unset CI_LOGGING_LOGFILENAME
    stopLogfile

    assertNull "CI_LOGGING_LOGFILENAME is null" "${CI_LOGGING_LOGFILENAME}"
}

testStopLogfile_file_not_writable() {

    # this create a new logfile
    local tmp=`mktemp`
    export CI_LOGGING_LOGFILENAME=${tmp}
    chmod 444  ${CI_LOGGING_LOGFILENAME}

    stopLogfile

    assertNull "CI_LOGGING_LOGFILENAME is not null" "${CI_LOGGING_LOGFILENAME}"

    rm -rf ${tmp}
}

testStopLogfile_file_is_writable() {

    # this create a new logfile
    local tmp=`mktemp`
    export CI_LOGGING_LOGFILENAME=${tmp}

    stopLogfile

    assertNull "CI_LOGGING_LOGFILENAME is null" "${CI_LOGGING_LOGFILENAME}"

    assertEquals "file is writable, no new file"  \
                 "`cat test/data/03_test2.txt`" \
                 "`cat ${tmp}`"

    rm -rf ${tmp}
}

source lib/shunit2

exit 0
