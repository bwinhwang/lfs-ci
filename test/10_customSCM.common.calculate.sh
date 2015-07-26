#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/customSCM.upstream.sh
source lib/customSCM.common.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    runOnMaster() {
        mockedCommand "runOnMaster $@" 
        echo ${MOCKED_DATA_readlink}
    }
    getBuildDirectoryOnMaster() {
        mockedCommand "getBuildDirectoryOnMaster $@" 
        echo /path/to/jenkins/jobs/job/build/lastSuccessfulBuild
    }

}
oneTimeTearDown() {
    rm -rf ${WORKSPACE}
    rm -rf ${REVISION_STATE_FILE}
}
tearDown() {
    unset UPSTREAM_BUILD
    unset UPSTREAM_PROJECT
    export UPSTREAM_BUILD
    export UPSTREAM_PROJECT
    unset MOCKED_DATA_readlink
    export MOCKED_DATA_readlink
}
setUp() {
    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/file.cfg
}

test1() {
    export UPSTREAM_BUILD=1
    export UPSTREAM_PROJECT=LFS_CI_-_FB1412_-_Test
    export JOB_NAME=LFS_CI_-_FB1412_-_Test_-_FSM-r3

    export REVISION_STATE_FILE=$(createTempFile)
    export WORKSPACE=$(createTempDirectory)

    assertTrue actionCalculate

    assertEquals "$(cat ${REVISION_STATE_FILE} | head -n 1)" "LFS_CI_-_FB1412_-_Test"
    assertEquals "$(cat ${REVISION_STATE_FILE} | tail -n 1)" "1"

    return
}
test2() {
    export UPSTREAM_BUILD=1
    export UPSTREAM_PROJECT=LFS_CI_-_FB1412_-_Test
    export JOB_NAME=LFS_CI_-_FB1412_-_Test_-_FSM-r3

    export REVISION_STATE_FILE=$(createTempFile)
    export WORKSPACE=$(createTempDirectory)

    assertTrue actionCalculate

    assertEquals "$(cat ${REVISION_STATE_FILE} | head -n 1)" "LFS_CI_-_FB1412_-_Test"
    assertEquals "$(cat ${REVISION_STATE_FILE} | tail -n 1)" "1"

    return
}

test3() {
    export REVISION_STATE_FILE=$(createTempFile)
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_FB1412_-_Test
    export MOCKED_DATA_readlink=1

    assertTrue actionCalculate

    assertEquals "LFS_CI_-_FB1412_-_SmokeTest" "$(cat ${REVISION_STATE_FILE} | head -n 1)" 
    assertEquals "1" "$(cat ${REVISION_STATE_FILE} | tail -n 1)" 

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getBuildDirectoryOnMaster LFS_CI_-_FB1412_-_SmokeTest lastSuccessfulBuild
runOnMaster readlink /path/to/jenkins/jobs/job/build/lastSuccessfulBuild
EOF

    assertEquals "$(cat ${UT_MOCKED_COMMANDS})" "$(cat ${expect})"

    return
}

source lib/shunit2

exit 0

