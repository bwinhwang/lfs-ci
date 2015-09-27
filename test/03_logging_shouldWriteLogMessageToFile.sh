#!/bin/bash

# source test/common.sh
source lib/logging.sh

test1() {
    assertFalse "test with FOOBAR" "shouldWriteLogMessageToFile FOOBAR"
    shouldWriteLogMessageToFile FOOBAR
}

test2() {
    assertTrue "test with INFO" "shouldWriteLogMessageToFile INFO"
}

source lib/shunit2

exit 0
