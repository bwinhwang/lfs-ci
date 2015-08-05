#!/bin/bash

source test/common.sh
source lib/uc_release_send_release_note.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            LFS_CI_uc_release_can_send_release_note) echo ${UT_CAN_SEND} ;;
            *) echo $1 ;;
        esac
    }
    execute() {
        mockedCommand "execute $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Build
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL=PS_LFS_REL_BUILD_NAME
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_CAN_SEND=1
    assertTrue "_sendReleaseNote"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_release_can_send_release_note
execute ${LFS_CI_ROOT}/bin/sendReleaseNote -r ${WORKSPACE}/workspace/os/releasenote.txt -t PS_LFS_REL_BUILD_NAME -f
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_CAN_SEND=
    assertTrue "_sendReleaseNote"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_release_can_send_release_note
EOF
    assertExecutedCommands ${expect}

    return
}


source lib/shunit2

exit 0
