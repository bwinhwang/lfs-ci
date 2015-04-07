#!/bin/bash

source test/common.sh
source lib/build.sh

oneTimeSetUp() {
    true
    getSvnLastChangedRevision() {
        echo 1234
    }
    getSvnUrl() {
        echo http://svn/path/to/$(basename $1)
    }
    normalizeSvnUrl() {
        echo $@
    }

}
oneTimeTearDown() {
    true
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export BUILD_NUMBER=1

    mkdir -p ${WORKSPACE}/workspace/
    mkdir -p ${WORKSPACE}/workspace/src-foo/.svn
    mkdir -p ${WORKSPACE}/workspace/src-bar/.svn
    mkdir -p ${WORKSPACE}/workspace/locations/DUMMY/.svn
    mkdir -p ${WORKSPACE}/workspace/bld-buildtools-common/.svn

}
tearDown() {
    true
}

test1() {
    assertTrue "storeRevisions fcmd"

    # just check result file
    local expect=$(createTempFile)
cat <<EOF > ${expect}
src-bar http://svn/path/to/src-bar 1234
src-foo http://svn/path/to/src-foo 1234
locations/DUMMY http://svn/path/to/DUMMY 1234
EOF
    assertEquals "$(cat ${expect})" \
                 "$(cat ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt
)"
    diff -rub ${expect} ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt

    return
}

source lib/shunit2

exit 0

