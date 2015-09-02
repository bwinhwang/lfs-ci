#!/bin/bash

source lib/common.sh
initTempDirectory

export UT_MOCKED_COMMANDS=$(createTempFile)

## @fn      assertExecutedCommands()
#  @brief   check for the executed commands in unit test
#  @param   {expect}    file with expected commands
#  @return  <none>
assertExecutedCommands() {
    local expect=$1
    local got=${2:-${UT_MOCKED_COMMANDS}}

    diff -u ${expect} ${got}
    assertEquals "$(cat ${expect})" "$(cat ${got})"

    return
}
