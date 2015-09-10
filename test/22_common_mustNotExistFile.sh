#!/bin/bash

source test/common.sh
source lib/common.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    return
}

setUp() {
#    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export LFS_CI_GLOBAL_PRODUCT_NAME=LFS
    return
}

tearDown() {
#    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test_without_parameter() {
    info Running test_without_parameter...
    assertFalse "mustNotExistFile"
    return
}

test_with_existing_file() {
    info Running test_with_existing_file...
    file=$(createTempFile)
    assertFalse "mustNotExistFile $file"
    return
}

test_with_non_existing_file() {
    info Running test_with_non_existing_file...
    file=$(createTempFile)
    rm -f $file
    assertTrue "mustNotExistFile $file"
    return
}


source lib/shunit2

exit 0

