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
        rc=0
        if [[ $5 = ${UT_FAIL_CAUSE} ]] ; then
            UT_EXECUTE_INSTALL=$(( UT_EXECUTE_INSTALL - 1))
            rc=${UT_EXECUTE_INSTALL}
        fi
        return ${rc}
                
    }
    _reserveTarget(){
        mockedCommand "_reserveTarget $@"
        echo "TargetName"
    }
    mustHaveMakingTestRunningTarget(){
        mockedCommand "mustHaveMakingTestRunningTarget $@"
    }
    mustHaveMakingTestTestConfig(){
        mockedCommand "mustHaveMakingTestTestConfig $@"
    }
    makingTest_testSuiteDirectory() {
        mockedCommand "makingTest_testSuiteDirectory $@"
        echo ${WORKSPACE}/workspace/path/to/test/suite
    }
#    mustExistDirectory() {
#        mockedCommand "mustExistDirectory $@"
#    }
    getConfig() {
        case $1 in
            LFS_CI_uc_test_making_test_do_firmwareupgrade)
                echo ${UT_CONFIG_FIRMWARE}
            ;;
            LFS_CI_uc_test_making_test_force_reinstall_same_version)
                echo ${UT_CONFIG_FORCE_REINSTALL}
            ;;
            LFS_CI_uc_test_should_target_be_running_before_make_install)
                echo ${UC_CONFIG_SHOULD_TARGET_RUN}
            ;;
            LFS_CI_uc_test_making_test_skip_steps_after_make_install)
                echo ${UT_CONFIG_SKIP_NEXT_STEPS}
            ;;
            LFS_CI_uc_test_making_test_installation_tries)
                echo ${UT_INSTALL_TRIED}
            ;;
        esac
    }
    sleep() {
        true
    }
    makingTest_powercycle() {
        mockedCommand "makingTest_powercycle $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/path/to/test/suite/
    touch ${WORKSPACE}/workspace/path/to/test/suite/testsuite.mk
    export UT_CONFIG_FORCE_REINSTALL=1
    export UT_CONFIG_FIRMWARE=
    export UC_CONFIG_SHOULD_TARGET_RUN=1
    export UT_INSTALL_TRIED=4
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # normal install, all ok
    export UT_EXECUTE_INSTALL=1
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    # install failed one time in make install
    export UT_EXECUTE_INSTALL=3
    export UT_FAIL_CAUSE=install
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    # install failed all the time
    export UT_EXECUTE_INSTALL=5
    export UT_FAIL_CAUSE=install
    assertFalse "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
execute make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
EOF
    assertExecutedCommands ${expect}

    return
}

test4() {
    # install is ok, but setup fails
    export UT_EXECUTE_INSTALL=2
    export UT_FAIL_CAUSE=setup
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}
test5() {
    # install is ok, but setup fails all the time
    export UT_EXECUTE_INSTALL=5
    export UT_FAIL_CAUSE=setup
    assertFalse "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
EOF
    assertExecutedCommands ${expect}

    return
}

test6() {
    # install and setup is ok, but check fails
    export UT_EXECUTE_INSTALL=2
    export UT_FAIL_CAUSE=check
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}

test7() {
    # install and setup is ok, but check fails all the time
    export UT_EXECUTE_INSTALL=5
    export UT_FAIL_CAUSE=check
    assertFalse "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
execute make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}

test8() {
    # firmware upgerade
    export UT_EXECUTE_INSTALL=1
    export UT_CONFIG_FIRMWARE=1
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite firmwareupgrade FORCED_UPGRADE=true
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}

test9() {
    # version is already installed and we are allowed to use it
    export UT_CONFIG_FORCE_REINSTALL=
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}

test10() {
    # version is already installed and we are allowed to use it
    export UT_EXECUTE_INSTALL=2
    export UT_FAIL_CAUSE=check
    export UT_CONFIG_FORCE_REINSTALL=
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite check
EOF
    assertExecutedCommands ${expect}

    return
}

test11() {
    # skip the next steps after make install
    export UT_CONFIG_SKIP_NEXT_STEPS=1
    assertTrue "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
EOF
    assertExecutedCommands ${expect}

    return
}

test12() {
    # install failed all the time
    export UT_EXECUTE_INSTALL=5
    export UT_INSTALL_TRIED=1
    export UT_FAIL_CAUSE=install
    assertFalse "makingTest_install"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
makingTest_testSuiteDirectory 
_reserveTarget 
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute make -C ${WORKSPACE}/workspace/path/to/test/suite install FORCE=yes
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
