#!/bin/bash

source test/common.sh

source lib/uc_admin_targets_power_off.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        echo ${UT_TARGETS}
    }
    getWorkspaceName() {
        mockedCommand "makingTest_testconfig $@"
        echo /path/to/ws
    }
    makingTest_testconfig() {
        mockedCommand "makingTest_testconfig $@"
    }
    makingTest_poweroff() {
        mockedCommand "makingTest_poweroff $@"
    }
    unreserveTarget() {
        mockedCommand "unreserveTarget $@"
    }
    reserveTargetByName() {
        mockedCommand "reserveTargetByName $@"
    }
    createBasicWorkspace() {
        mockedCommand "createBasicWorkspace $@"
    }
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_TARGETS="a b c"
    assertTrue "usecase_ADMIN_TARGETS_POWER_OFF"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
createBasicWorkspace -l pronb-developer src-test
makingTest_testconfig 
makingTest_testconfig 
execute -n ${LFS_CI_ROOT}/bin/unusedTargets
reserveTargetByName a
makingTest_testconfig 
makingTest_poweroff 
unreserveTarget 
reserveTargetByName b
makingTest_testconfig 
makingTest_poweroff 
unreserveTarget 
reserveTargetByName c
makingTest_testconfig 
makingTest_poweroff 
unreserveTarget 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_TARGETS=""
    assertTrue "usecase_ADMIN_TARGETS_POWER_OFF"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
createBasicWorkspace -l pronb-developer src-test
makingTest_testconfig 
makingTest_testconfig 
execute -n ${LFS_CI_ROOT}/bin/unusedTargets
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
