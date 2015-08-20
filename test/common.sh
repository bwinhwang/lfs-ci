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

    diff -u ${expect} ${UT_MOCKED_COMMANDS}
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}
