#!/bin/bash

source test/common.sh
source lib/build.sh

oneTimeSetUp() {
    true
}
oneTimeTearDown() {
    true
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export SHARE=$(createTempDirectory)

    mkdir -p ${SHARE}/pkgpool/PKGPOOL_123
    mkdir -p ${SHARE}/sdk/SDK_123
    mkdir -p ${SHARE}/sdk2/SDK3_123

    local workspace=${WORKSPACE}/workspace/
    mkdir -p ${workspace}/bld/
    ln -sf ${SHARE}/pkgpool/PKGPOOL_123 ${workspace}/bld/pkgpool
    ln -sf ${SHARE}/sdk/SDK_123 ${workspace}/bld/sdk
    ln -sf ${SHARE}/sdk2/SDK3_123 ${workspace}/bld/sdk2

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd

}
tearDown() {
    true
}

test1() {

    assertTrue "storeExternalComponentBaselines"

    # just check result file
    local expect=$(createTempFile)
cat <<EOF > ${expect}
sdk <> = SDK_123
sdk2 <> = SDK3_123
pkgpool <> = PKGPOOL_123
EOF
    assertEquals "$(cat ${expect})" \
                 "$(cat ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents)"


    return
}

source lib/shunit2

exit 0

