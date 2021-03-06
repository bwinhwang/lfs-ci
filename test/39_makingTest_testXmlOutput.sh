#!/bin/bash

source test/common.sh

source lib/makingtest.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    _reserveTarget(){
        mockedCommand "_reserveTarget $@"
        echo "TargetName"
    }
    makingTest_testSuiteDirectory(){
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo /path/to/test/suite
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
    }
    mustHaveMakingTestTestConfig() {
        mockedCommand "mustHaveMakingTestTestConfig $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        if [[ $1 == LFS_CI_uc_test_making_test_timeout_in_seconds_for_make_test ]] ; then
            echo 10800
            return
        fi                
        echo ${UT_TMF_TEST_OPTIONS}

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
    assertTrue "makingTest_testXmloutput"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/xml-output
mustExistDirectory ${WORKSPACE}/workspace/xml-output
makingTest_testSuiteDirectory 
mustExistDirectory /path/to/test/suite
getConfig LFS_CI_uc_test_making_test_test_options
mustHaveMakingTestTestConfig 
getConfig LFS_CI_uc_test_making_test_timeout_in_seconds_for_make_test
execute timeout -s 9 10800 make -C /path/to/test/suite --ignore-errors test-xmloutput
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_TMF_TEST_OPTIONS="TEST=1 OPTION=2"

    assertTrue "makingTest_testXmloutput"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/xml-output
mustExistDirectory ${WORKSPACE}/workspace/xml-output
makingTest_testSuiteDirectory 
mustExistDirectory /path/to/test/suite
getConfig LFS_CI_uc_test_making_test_test_options
mustHaveMakingTestTestConfig 
getConfig LFS_CI_uc_test_making_test_timeout_in_seconds_for_make_test
execute timeout -s 9 10800 make -C /path/to/test/suite --ignore-errors ${UT_TMF_TEST_OPTIONS} test-xmloutput
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
