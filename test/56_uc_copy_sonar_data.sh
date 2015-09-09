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
            jenkinsMasterServerPath)            echo ${JENKINS_ROOT}/home ;;
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
    export JENKINS_ROOT=$(createTempDirectory)
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
    assertTrue "usecase_LFS_COPY_SONAR_DATA"
    
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3-UT_-_fsmr3_fsmddal
    check_FilesExist

    return
}

test_FSMr4() {
    assertTrue "usecase_LFS_COPY_SONAR_DATA"

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4-UT_-_fsmr4_fsmddal
    check_FilesExist

    return
}

check_FilesExist() {
    # check that files exist
    local targetType=$(getSubTaskNameFromJobName)
    assertTrue "coverage.xml.gz not found!"         "[[ -e ${JENKINS_ROOT}/home/userContent/sonar/${targetType}/coverage.xml.gz ]]"
    assertTrue "testcases.merged.xml.gz not found!" "[[ -e ${JENKINS_ROOT}/home/userContent/sonar/${targetType}/testcases.merged.xml.gz ]]"

    return
}

source lib/shunit2

exit 0

