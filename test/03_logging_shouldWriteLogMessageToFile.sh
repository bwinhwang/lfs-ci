#!/bin/bash

source test/common.sh
source lib/logging.sh

test1() {
    assertFalse "shouldWriteLogMessageToFile FOOBAR"    
}

test2() {
    assertFalse "shouldWriteLogMessageToFile INFO"    
}

source lib/shunit2

exit 0
