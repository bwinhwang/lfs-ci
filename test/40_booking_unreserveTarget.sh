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
    getConfig() {
        echo ${LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER}
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
    unset LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER
    export LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER
    assertTrue "unreserveTarget"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/unreserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    unset LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER
    export LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER
    assertTrue "unreserveTarget 1"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/unreserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}
test3() {
    export LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER=1
    assertTrue "unreserveTarget 1"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/unreserveTarget --targetName=targetName
execute ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName --userName=doRepair --comment=red target by no job name / no build number
EOF
    assertExecutedCommands ${expect}

    return
}
test4() {
    unset LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER
    export LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER
    assertTrue "unreserveTarget 0"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/unreserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

test5() {
    export LFS_CI_BOOKING_MOVE_TARGET_TO_REPAIR_CENTER=1
    assertTrue "unreserveTarget 0"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/unreserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
