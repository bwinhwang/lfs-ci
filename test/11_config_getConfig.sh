#!/bin/bash

source test/common.sh
source lib/config.sh

oneTimeSetUp() {
    export UT_CFG_FILE=$(createTempFile)
    echo "a                   = 1" >> ${UT_CFG_FILE}
    echo "b                   = 2" >> ${UT_CFG_FILE}
    echo "c                   = 3" >> ${UT_CFG_FILE}
    echo "c < b:1           > = 4" >> ${UT_CFG_FILE}
    echo "c < b:1, a:1      > = 5" >> ${UT_CFG_FILE}
    echo "c < b:1, a:1, x:9 > = 6" >> ${UT_CFG_FILE}
    echo "d < b:1           > = 4" >> ${UT_CFG_FILE}

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    return
}
oneTimeTearDown() {
    true
}

test1() {
    export LFS_CI_CONFIG_FILE=${UT_CFG_FILE}
    local value=$(getConfig a)
    assertEquals "1" "${value}"
}

test2() {
    unset LFS_CI_CONFIG_FILE
    export LFS_CI_CONFIG_FILE
    local value=$(getConfig a -f ${UT_CFG_FILE})
    assertEquals "1" "${value}"
}

test3() {
    local value=$(getConfig d -f ${UT_CFG_FILE} -t b:1)
    assertEquals "4" "${value}"
}

test4() {
    # match for b and a (via file)
    local value=$(getConfig c -f ${UT_CFG_FILE} -t b:1)
    assertEquals "5" "${value}"
}

test5() {
    # match for b and a (via file)
    local value=$(getConfig c -f ${UT_CFG_FILE} -t b:1 -t x:9 )
    assertEquals "6" "${value}"
}

source lib/shunit2

exit 0

