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
        if [[ $2 == make && $6 == "testtarget-analyzer" ]] ; then
            echo "moxa=127.123.123.123:1234"
            echo "setupfsps=${UT_CONNECTED_FSPS}"
        fi
        if [[ $2 == make && $6 == testroot ]] ; then
            echo ${UT_TESTROOT}
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
    export UT_TESTROOT=$(createTempDirectory)
    mkdir -p ${UT_TESTROOT}/targets
    echo "moxa=127.123.123.123:1234" > ${UT_TESTROOT}/targets/targetname
    echo "moxa=127.123.123.123:1234" > ${UT_TESTROOT}/targets/targeta
    echo "moxa=127.123.123.123:1234" > ${UT_TESTROOT}/targets/targetname_fsp1
    echo "moxa=127.123.123.123:1234" > ${UT_TESTROOT}/targets/targetname_fsp2
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # assertTrue "makingTest_logConsole"
    makingTest_logConsole

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_test_should_record_log_output_of_target
makingTest_testSuiteDirectory 
mustHaveMakingTestTestConfig 
execute mkdir -p ${WORKSPACE}/workspace/path/to/test/suite/__artifacts
execute chmod 755 ${WORKSPACE}/workspace/makeConsoleWrapper
_reserveTarget 
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testtarget-analyzer
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testroot
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testtarget-analyzer TESTTARGET=targetname
execute sed -i s/moxa=127.123.123.123:1234/moxa=localhost:64258/g ${UT_TESTROOT}/targets/targetname
execute screen -S lfs-jenkins.${USER}.targetName -L -d -m -c ${WORKSPACE}/workspace/screenrc
exit_add makingTest_collectArtifactsOnFailure
exit_add makingTest_closeConsole
EOF
    assertExecutedCommands ${expect}

    cat <<EOF > ${expect}
logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/console.%n
logfile flush 1
logtstamp after 10
screen -L -t tp_targetname ${LFS_CI_ROOT}/lib/contrib/tcp_sharer/tcp_sharer.pl --name targetname --logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/tp_targetname.log --remote 127.123.123.123:1234 --local 64258
screen -L -t targetname ${WORKSPACE}/workspace/makeConsoleWrapper ${WORKSPACE}/workspace/path/to/test/suite targetname
EOF
    diff -rub ${expect} ${WORKSPACE}/workspace/screenrc
    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/workspace/screenrc)"

    cat <<EOF > ${expect}
#!/usr/bin/env bash
set -x
sleep 1
make -C \$1 TESTTARGET=\$2 console
exit 0
EOF
    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/workspace/makeConsoleWrapper)"

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
execute chmod 755 ${WORKSPACE}/workspace/makeConsoleWrapper
_reserveTarget 
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testtarget-analyzer
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testroot
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testtarget-analyzer TESTTARGET=targetname
execute sed -i s/moxa=127.123.123.123:1234/moxa=localhost:64258/g ${UT_TESTROOT}/targets/targetname
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testtarget-analyzer TESTTARGET=targetname_fsp1
execute sed -i s/moxa=127.123.123.123:1234/moxa=localhost:64258/g ${UT_TESTROOT}/targets/targetname_fsp1
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testtarget-analyzer TESTTARGET=targetname_fsp2
execute sed -i s/moxa=127.123.123.123:1234/moxa=localhost:64258/g ${UT_TESTROOT}/targets/targetname_fsp2
execute screen -S lfs-jenkins.${USER}.targetName -L -d -m -c ${WORKSPACE}/workspace/screenrc
exit_add makingTest_collectArtifactsOnFailure
exit_add makingTest_closeConsole
EOF
    assertExecutedCommands ${expect}

    cat <<EOF > ${expect}
logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/console.%n
logfile flush 1
logtstamp after 10
screen -L -t tp_targetname ${LFS_CI_ROOT}/lib/contrib/tcp_sharer/tcp_sharer.pl --name targetname --logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/tp_targetname.log --remote 127.123.123.123:1234 --local 64258
screen -L -t targetname ${WORKSPACE}/workspace/makeConsoleWrapper ${WORKSPACE}/workspace/path/to/test/suite targetname
screen -L -t tp_targetname_fsp1 ${LFS_CI_ROOT}/lib/contrib/tcp_sharer/tcp_sharer.pl --name targetname_fsp1 --logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/tp_targetname_fsp1.log --remote 127.123.123.123:1234 --local 64258
screen -L -t targetname_fsp1 ${WORKSPACE}/workspace/makeConsoleWrapper ${WORKSPACE}/workspace/path/to/test/suite targetname_fsp1
screen -L -t tp_targetname_fsp2 ${LFS_CI_ROOT}/lib/contrib/tcp_sharer/tcp_sharer.pl --name targetname_fsp2 --logfile ${WORKSPACE}/workspace/path/to/test/suite/__artifacts/tp_targetname_fsp2.log --remote 127.123.123.123:1234 --local 64258
screen -L -t targetname_fsp2 ${WORKSPACE}/workspace/makeConsoleWrapper ${WORKSPACE}/workspace/path/to/test/suite targetname_fsp2
EOF
    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/workspace/screenrc)"
    diff -rub ${expect} ${WORKSPACE}/workspace/screenrc

    cat <<EOF > ${expect}
#!/usr/bin/env bash
set -x
sleep 1
make -C \$1 TESTTARGET=\$2 console
exit 0
EOF
    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/workspace/makeConsoleWrapper)"

    return
}

test4() {
    # if there is no test root, no console logging is possible
    export UT_TESTROOT=
    assertTrue "makingTest_logConsole"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_uc_test_should_record_log_output_of_target
makingTest_testSuiteDirectory 
mustHaveMakingTestTestConfig 
execute mkdir -p ${WORKSPACE}/workspace/path/to/test/suite/__artifacts
execute chmod 755 ${WORKSPACE}/workspace/makeConsoleWrapper
_reserveTarget 
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testtarget-analyzer
execute -n make -C ${WORKSPACE}/workspace/path/to/test/suite --no-print-directory testroot
EOF
    assertExecutedCommands ${expect}

    return
}


source lib/shunit2

exit 0
