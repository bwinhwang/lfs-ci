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
        if [[ $1 == mkdir ]] ; then
            $@
        fi
        if [[ $2 == make ]] ; then
            echo "setupfsps=${UT_CONNECTED_FSPS}"
        fi
    }
    mustHaveMakingTestTestConfig(){
        mockedCommand "mustHaveMakingTestTestConfig $@"
    }
    makingTest_testSuiteDirectory() {
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo ${WORKSPACE}/workspace/path/to/test/suite
    }
    _reserveTarget() {
        mockedCommand "_reserveTarget $@"
        echo "targetName"
    }
    exit_add() {
        mockedCommand "exit_add $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo ${UT_CONFIG_SHOULD_LOG}
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/path/to/test/suite
    touch ${WORKSPACE}/workspace/path/to/test/suite/testsuite.mk
    export UT_CONFIG_SHOULD_LOG=1
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "makingTest_logConsole"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_test_should_record_log_output_of_target
makingTest_testSuiteDirectory 
mustHaveMakingTestTestConfig 
execute mkdir -p ${WORKSPACE}/workspace/path/to/test/suite/__artifacts
_reserveTarget 
execute -n make testtarget-analyzer TESTTARGET=targetName
execute screen -S lfs-jenkins.${USER}.targetName -L -d -m -c ${WORKSPACE}/workspace/screenrc
exit_add makingTest_closeConsole
EOF
    assertExecutedCommands ${expect}

    cat <<EOF > ${expect}
logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/console.%n
logfile flush 1
logtstamp after 10
screen -L -t targetname make -C ${WORKSPACE}/workspace/path/to/test/suite TESTTARGET=targetname console
EOF
    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/workspace/screenrc)"
    diff -rub ${expect} ${WORKSPACE}/workspace/screenrc

    return
}

test2() {
    export UT_CONFIG_SHOULD_LOG=
    assertTrue "makingTest_logConsole"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_test_should_record_log_output_of_target
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    export UT_CONNECTED_FSPS="targetName_fsp1,targetName_fsp2"
    assertTrue "makingTest_logConsole"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_test_should_record_log_output_of_target
makingTest_testSuiteDirectory 
mustHaveMakingTestTestConfig 
execute mkdir -p ${WORKSPACE}/workspace/path/to/test/suite/__artifacts
_reserveTarget 
execute -n make testtarget-analyzer TESTTARGET=targetName
execute screen -S lfs-jenkins.${USER}.targetName -L -d -m -c ${WORKSPACE}/workspace/screenrc
exit_add makingTest_closeConsole
EOF
    assertExecutedCommands ${expect}

    cat <<EOF > ${expect}
logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/console.%n
logfile flush 1
logtstamp after 10
screen -L -t targetname make -C ${WORKSPACE}/workspace/path/to/test/suite TESTTARGET=targetname console
screen -L -t targetname_fsp1 make -C ${WORKSPACE}/workspace/path/to/test/suite TESTTARGET=targetname_fsp1 console
screen -L -t targetname_fsp2 make -C ${WORKSPACE}/workspace/path/to/test/suite TESTTARGET=targetname_fsp2 console
EOF
    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/workspace/screenrc)"
    diff -rub ${expect} ${WORKSPACE}/workspace/screenrc

    return
}

source lib/shunit2

exit 0
