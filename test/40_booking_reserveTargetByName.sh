#!/bin/bash

source test/common.sh

source lib/booking.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        for i in 1 2 3 4 ; do
            if [[ -e ${WORKSPACE}/.error_${i} ]] ; then
                rm -rf ${WORKSPACE}/.error_${i}
                return 1
            fi
        done
    }
    getConfig(){
        mockedCommand "getConfig $@"
        case $1 in
            LFS_uc_test_booking_target_sleep_seconds) echo 1 ;;
            LFS_uc_test_booking_target_max_tries)     echo 3 ;;
        esac
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
    assertTrue "reserveTargetByName targetName"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    touch ${WORKSPACE}/.error_1
    assertTrue "reserveTargetByName targetName"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    touch ${WORKSPACE}/.error_{1,2}
    assertTrue "reserveTargetByName targetName"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

test4() {
    touch ${WORKSPACE}/.error_{1,2,3}
    assertFalse "reserveTargetByName targetName"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=targetName
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
