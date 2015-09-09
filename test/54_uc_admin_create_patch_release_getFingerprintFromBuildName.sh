#!/bin/bash

source test/common.sh
source lib/fingerprint.sh

oneTimeSetUp() {
    return
}

setUp() {
   return
}

tearDown() {
    return
}

test1() {
    build=PS_LFS_OS_2015_08_0001

    assertEquals "282eac4e982891fd8eff35808ec9b7d7" "$(getFingerprintFromBuildName ${build})"
}

source lib/shunit2

exit 0
