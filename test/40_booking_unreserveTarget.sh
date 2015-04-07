#!/bin/bash

source test/common.sh

source lib/booking.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export LFS_CI_BOOKING_RESERVED_TARGET=targetName
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "unreserveTarget"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/unreserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
