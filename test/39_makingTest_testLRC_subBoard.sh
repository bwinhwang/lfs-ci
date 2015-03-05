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
        if [[ $1 = mkdir ]] ; then
            shift
            mkdir $@
        fi
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
    getConfig() {
        case $1 in
            LFS_CI_uc_test_making_test_do_firmwareupgrade)
                echo ${UT_CONFIG_FIRMWARE}
            ;;
        esac
    }
    sleep() {
        true
    }
    makingTest_poweroff() {
        mockedCommand "makingTest_poweroff $@"
    }
    makingTest_powercycle() {
        mockedCommand "makingTest_powercycle $@"
    }
    makingTest_install() {
        mockedCommand "makingTest_install $@"
    }
    makingTest_check() {
        mockedCommand "makingTest_check $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export DELIVERY_DIRECTORY=$(createTempDirectory)
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/xml-output/
    for dir in ${WORKSPACE}/workspace/path/to/test/suite 
    do
        mkdir -p ${dir}
        touch ${dir}/testsuite.mk
    done
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "makingTest_testLRC_subBoard ${WORKSPACE}/workspace/path/to/test/suite  ${DELIVERY_DIRECTORY} targetName prefix ${WORKSPACE}/xml-output"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/xml-output
execute make -C ${WORKSPACE}/workspace/path/to/test/suite clean
execute make -C ${WORKSPACE}/workspace/path/to/test/suite testconfig-overwrite TESTBUILD=${DELIVERY_DIRECTORY} TESTTARGET=targetName
execute make -C ${WORKSPACE}/workspace/path/to/test/suite setup
execute make -C ${WORKSPACE}/workspace/path/to/test/suite check
execute -i make -C ${WORKSPACE}/workspace/path/to/test/suite -i test-xmloutput
execute mkdir -p ${WORKSPACE}/xml-output
execute cp -rf ${WORKSPACE}/workspace/path/to/test/suite/xml-reports/* ${WORKSPACE}/xml-output/
execute sed -i -s s/name="/name="prefix_/g ${WORKSPACE}/xml-output/*.xml
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
