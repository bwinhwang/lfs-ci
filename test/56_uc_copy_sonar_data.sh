#!/bin/bash

source test/common.sh
source lib/config.sh
source lib/uc_sonar_data.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    
    getConfig() {
        mockedCommand "getConfig $@"
        case ${1} in
            jenkinsMasterServerHostName)        echo localhost ;;
            jenkinsMasterServerPath)            echo ${jenkinsRoot}/home ;;
            LFS_CI_unittest_coverage_data_path) echo bld/bld-unittests-fsmr3_fsmddal/results/__artifacts ;;
            *)                                  echo $1
        esac

        return
    }

    getWorkspaceName() {
        mockedCommand "getWorkspaceName $@"
        echo ${WORKSPACE}

        return
    }

    return
}

oneTimeTearDown() {
    
    return
}

setUp() {
    export WORKSPACE=$(createTempDirectory)
    export jenkinsRoot=$(createTempDirectory)
    export SONAR_DATA_PATH=$(getConfig LFS_CI_unittest_coverage_data_path)
    mkdir -p ${WORKSPACE}/${SONAR_DATA_PATH}
    touch ${WORKSPACE}/${SONAR_DATA_PATH}/coverage.xml.gz
    touch ${WORKSPACE}/${SONAR_DATA_PATH}/testcases.merged.xml.gz

    return
}

tearDown() {
    # rm -rf ${WORKSPACE}
    return 
}

test_FSMr3() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3-UT_-_fsmr3_fsmddal
    assertTrue "usecase_LFS_COPY_SONAR_DATA"
    
    # check that files exist
    local TARGET_TYPE=$(getSubTaskNameFromJobName)
    assertTrue "coverage.xml.gz not found!"         "[[ -e ${jenkinsRoot}/home/userContent/sonar/${TARGET_TYPE}/coverage.xml.gz ]]"
    assertTrue "testcases.merged.xml.gz not found!" "[[ -e ${jenkinsRoot}/home/userContent/sonar/${TARGET_TYPE}/testcases.merged.xml.gz ]]"


    return
}

test_FSMr4() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4-UT_-_fsmr4_fsmddal
    assertTrue "usecase_LFS_COPY_SONAR_DATA"
    
    # check that files exist
    local TARGET_TYPE=$(getSubTaskNameFromJobName)
    assertTrue "coverage.xml.gz not found!"         "[[ -e ${jenkinsRoot}/home/userContent/sonar/${TARGET_TYPE}/coverage.xml.gz ]]"
    assertTrue "testcases.merged.xml.gz not found!" "[[ -e ${jenkinsRoot}/home/userContent/sonar/${TARGET_TYPE}/testcases.merged.xml.gz ]]"


    return
}

source lib/shunit2

exit 0

