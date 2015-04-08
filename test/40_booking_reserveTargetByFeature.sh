#!/bin/bash

source test/common.sh

source lib/booking.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        for i in 1 2 3 4 5 6 7 8 ; do
            if [[ -e ${WORKSPACE}/.cmd_${i} ]] ; then
                info cmd $@
                cat ${WORKSPACE}/.cmd_${i}
                rm -rf ${WORKSPACE}/.cmd_${i}
                return
            fi
            if [[ -e ${WORKSPACE}/.error_${i} ]] ; then
                info error $@
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
    echo "target1" > ${WORKSPACE}/.cmd_1

    assertTrue "reserveTargetByFeature feature1"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -n ${LFS_CI_ROOT}/bin/searchTarget --attribute=feature1
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=target1
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    echo "target1" > ${WORKSPACE}/.cmd_1

    assertTrue "reserveTargetByFeature feature1 feature2"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -n ${LFS_CI_ROOT}/bin/searchTarget --attribute=feature1 --attribute=feature2
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=target1
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    # search a target and reserve it in 2nd try
    echo "target1" > ${WORKSPACE}/.cmd_1
    echo "target1" > ${WORKSPACE}/.cmd_3
    echo "target1" > ${WORKSPACE}/.cmd_5
    touch ${WORKSPACE}/.error_2 # error in reservation

    assertTrue "reserveTargetByFeature feature1 feature2"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -n ${LFS_CI_ROOT}/bin/searchTarget --attribute=feature1 --attribute=feature2
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=target1
execute -n ${LFS_CI_ROOT}/bin/searchTarget --attribute=feature1 --attribute=feature2
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=target1
EOF
    assertExecutedCommands ${expect}

    return
}

test4() {
    # search a target and reserve it in 2nd try
    echo "target1" > ${WORKSPACE}/.cmd_1
    echo "target1" > ${WORKSPACE}/.cmd_3
    echo "target1" > ${WORKSPACE}/.cmd_5
    touch ${WORKSPACE}/.error_2 # error in reservation
    touch ${WORKSPACE}/.error_4 # error in reservation
    touch ${WORKSPACE}/.error_6 # error in reservation

    assertFalse "reserveTargetByFeature feature1 feature2"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_test_booking_target_sleep_seconds
getConfig LFS_uc_test_booking_target_max_tries
execute -n ${LFS_CI_ROOT}/bin/searchTarget --attribute=feature1 --attribute=feature2
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=target1
execute -n ${LFS_CI_ROOT}/bin/searchTarget --attribute=feature1 --attribute=feature2
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=target1
execute -n ${LFS_CI_ROOT}/bin/searchTarget --attribute=feature1 --attribute=feature2
execute -i ${LFS_CI_ROOT}/bin/reserveTarget --targetName=target1
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
