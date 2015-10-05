#!/bin/bash

source test/common.sh

source lib/booking.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig(){
        mockedCommand "getConfig $@"
        case $1 in
            LFS_uc_test_is_booking_enabled) echo ${UT_CONFIG_BOOKING_ENABLED} ;;
            LFS_uc_test_booking_target_features) echo feature1 feature2 ;;
        esac
    }
    reserveTargetByFeature() {
        mockedCommand "reserveTargetByFeature $@"
    }
    reservedTarget() {
        mockedCommand "reservedTarget $@"
        echo targetName
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export JOB_NAME=LFS_CI_-_trunk_-_Test_-_FSM-r3_-_target
    export UT_CONFIG_BOOKING_ENABLED=1

    # assertTrue "mustHaveReservedTarget"
    mustHaveReservedTarget

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_is_booking_enabled
getConfig LFS_uc_test_booking_target_features -t branchName:trunk
reserveTargetByFeature feature1 feature2
reservedTarget 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    echo "target1" > ${WORKSPACE}/.cmd_1
    export JOB_NAME=Test-targetName
    export UT_CONFIG_BOOKING_ENABLED=

    # assertTrue "mustHaveReservedTarget"
    mustHaveReservedTarget

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_is_booking_enabled
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
