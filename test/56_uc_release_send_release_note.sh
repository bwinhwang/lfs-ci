#!/bin/bash

source test/common.sh
source lib/uc_release_send_release_note.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustBePreparedForReleaseTask() {
        mockedCommand "mustBePreparedForReleaseTask $@"
    }
    _sendReleaseNote() {
        mockedCommand "_sendReleaseNote $@"
    }
    _workflowToolCreateRelease() {
        mockedCommand "_workflowToolCreateRelease $@"
    }
    _storeArtifactsFromRelease() {
        mockedCommand "_storeArtifactsFromRelease $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_RELEASE_SEND_RELEASE_NOTE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
_workflowToolCreateRelease 
_sendReleaseNote 
_storeArtifactsFromRelease 
EOF
    assertExecutedCommands ${expect}

    return
}


source lib/shunit2

exit 0
