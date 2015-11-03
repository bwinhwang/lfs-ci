#!/bin/bash

source test/common.sh

source lib/makingtest.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    _reserveTarget(){
        mockedCommand "_reserveTarget $@"
        echo "TargetName"
    }
    getConfig(){
        mockedCommand "getConfig $@"
        echo ${UT_FAKE_TEST_SUITE}
    }
    getLocationName() {
        echo pronb-developer
    }
    getBranchName() {
        echo trunk
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Package_-_package
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/path/to/test/suite
    touch ${WORKSPACE}/workspace/path/to/test/suite/testsuite.mk
    mkdir -p ${WORKSPACE}/workspace/my/branched/test_suite
    touch ${WORKSPACE}/workspace/my/branched/test_suite/testsuite.mk
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_FAKE_TEST_SUITE=path/to/test/suite
    assertTrue "makingTest_testSuiteDirectory"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_reserveTarget 
getConfig LFS_CI_uc_test_making_test_suite_dir -t targetName:TargetName -t branchName:trunk
EOF
    assertExecutedCommands ${expect}
    assertEquals "${WORKSPACE}/workspace/path/to/test/suite" "$(makingTest_testSuiteDirectory)"

    return
}

test2() {
    mkdir -p ${WORKSPACE}/workspace/src-project/src/TMF
    touch ${WORKSPACE}/workspace/src-project/src/TMF/testsuites.cfg
    export UT_FAKE_TEST_SUITE=my/branched/test_suite

    assertTrue "makingTest_testSuiteDirectory"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_reserveTarget 
getConfig test_suite -t targetName:TargetName -t branchName:trunk -f ${WORKSPACE}/workspace/src-project/src/TMF/testsuites.cfg
EOF
    assertExecutedCommands ${expect}
    assertEquals "${WORKSPACE}/workspace/my/branched/test_suite" "$(makingTest_testSuiteDirectory)"

    return
}
source lib/shunit2

exit 0
