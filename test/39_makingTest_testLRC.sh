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
    makingTest_testLRC_check() {
        mockedCommand "makingTest_check $@"
    }
    makingTest_testLRC_subBoard() {
        mockedCommand "makingTest_testLRC_subBoard $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export DELIVERY_DIRECTORY=$(createTempDirectory)
    export WORKSPACE=$(createTempDirectory)
    for dir in ${WORKSPACE}/workspace/path/to/test/suite \
               ${WORKSPACE}/workspace/path/to/test/suite_ahp/ \
               ${WORKSPACE}/workspace/path/to/test/suite_shp/
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
    # normal install, all ok
    assertTrue "makingTest_testLRC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/xml-reports
_reserveTarget 
makingTest_testSuiteDirectory 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite clean
execute make -C ${WORKSPACE}/workspace/path/to/test/suite testconfig-overwrite TESTBUILD=${DELIVERY_DIRECTORY} TESTTARGET=TargetName
execute make -C ${WORKSPACE}/workspace/path/to/test/suite_ahp testconfig-overwrite TESTBUILD=${DELIVERY_DIRECTORY} TESTTARGET=TargetName_ahp
execute make -C ${WORKSPACE}/workspace/path/to/test/suite_shp testconfig-overwrite TESTBUILD=${DELIVERY_DIRECTORY} TESTTARGET=TargetName_shp
makingTest_powercycle 
mustHaveMakingTestRunningTarget 
makingTest_install 
makingTest_check ${WORKSPACE}/workspace/path/to/test/suite TargetName
makingTest_check ${WORKSPACE}/workspace/path/to/test/suite_shp TargetName_shp
makingTest_check ${WORKSPACE}/workspace/path/to/test/suite_ahp TargetName_ahp
makingTest_testLRC_subBoard ${WORKSPACE}/workspace/path/to/test/suite_shp ${DELIVERY_DIRECTORY} TargetName_shp shp ${WORKSPACE}/workspace/xml-reports/shp
makingTest_testLRC_subBoard ${WORKSPACE}/workspace/path/to/test/suite ${DELIVERY_DIRECTORY} TargetName_shp shp-common ${WORKSPACE}/workspace/xml-reports/shp-common
mustHaveMakingTestRunningTarget 
execute make -C ${WORKSPACE}/workspace/path/to/test/suite_ahp setup
execute make -C ${WORKSPACE}/workspace/path/to/test/suite_ahp check
makingTest_testLRC_subBoard ${WORKSPACE}/workspace/path/to/test/suite_ahp ${DELIVERY_DIRECTORY} TargetName_ahp ahp ${WORKSPACE}/workspace/xml-reports/ahp
makingTest_testLRC_subBoard ${WORKSPACE}/workspace/path/to/test/suite ${DELIVERY_DIRECTORY} TargetName_ahp ahp-common ${WORKSPACE}/workspace/xml-reports/ahp-common
makingTest_poweroff 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
