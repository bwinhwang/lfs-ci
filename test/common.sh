#!/bin/bash

source lib/common.sh
initTempDirectory

export UT_MOCKED_COMMANDS=$(createTempFile)

assertExecutedCommands() {
    local expect=$1

    diff -rub ${expect} ${UT_MOCKED_COMMANDS}
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}
