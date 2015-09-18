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
            LFS_CI_unittest_coverage_data_path) echo ${DATA_PATH} ;;
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
    # export WORKSPACE=$(createTempDirectory)
    # export JENKINS_ROOT=$(createTempDirectory)
    export WORKSPACE=/tmp/vm048635/workspace
    export JENKINS_ROOT=/tmp/vm048635/jenkinsroot

    for TARGET in fsmr3 fsmr4 
    do
        export DATA_PATH=bld/bld-unittests-${TARGET}_fsmddal/results/__artifact
        export SONAR_DATA_PATH=$(getConfig LFS_CI_unittest_coverage_data_path)
        mkdir -p ${WORKSPACE}/${SONAR_DATA_PATH}
        touch ${WORKSPACE}/${SONAR_DATA_PATH}/coverage.xml.gz
        touch ${WORKSPACE}/${SONAR_DATA_PATH}/testcases.merged.xml.gz
    done

    for TARGET in FSMr3 FSMr4 
    do
        export DATA_PATH=src-test/src/unittest/testsuites/continousintegration/coverage/summary/__html/LCOV_${TARGET}
        export SONAR_DATA_PATH=$(getConfig LFS_CI_unittest_coverage_data_path)
        mkdir -p ${WORKSPACE}/${SONAR_DATA_PATH}
        touch ${WORKSPACE}/${SONAR_DATA_PATH}/coverage.xml.gz
        touch ${WORKSPACE}/${SONAR_DATA_PATH}/testcases.merged.xml.gz
    done

    return
}

tearDown() {
    # rm -rf ${WORKSPACE}
    return 
}

test_UT_FSMr3() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3-UT_-_fsmr3_fsmddal
    export DATA_PATH=bld/bld-unittests-fsmr3_fsmddal/results/__artifact
    assertTrue "usecase_LFS_COPY_SONAR_UT_DATA for FSMr3 failed!" "usecase_LFS_COPY_SONAR_UT_DATA"
    
    local targetType=$(getSubTaskNameFromJobName)
    local sonarPath=sonar/UT/${targetType}
    check_FilesExist ${sonarPath}

    return
}

test_UT_FSMr4() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4-UT_-_fsmr4_fsmddal
    export DATA_PATH=bld/bld-unittests-fsmr4_fsmddal/results/__artifact
    assertTrue "usecase_LFS_COPY_SONAR_UT_DATA for FSMr4 failed!" "usecase_LFS_COPY_SONAR_UT_DATA"

    local targetType=$(getSubTaskNameFromJobName)
    local sonarPath=sonar/UT/${targetType}
    check_FilesExist ${sonarPath}

    return
}

test_SCT() {
    export DATA_PATH='src-test/src/unittest/testsuites/continousintegration/coverage/summary/__html/LCOV_${targetType}'
    assertTrue "usecase_LFS_COPY_SONAR_SCT_DATA failed!" "usecase_LFS_COPY_SONAR_SCT_DATA"
    
    local sonarPath=sonar/SCT/FSMr3
    check_FilesExist ${sonarPath}
    local sonarPath=sonar/SCT/FSMr4
    check_FilesExist ${sonarPath}

    return
}

check_FilesExist() {
    # check that files exist
    assertTrue "coverage.xml.gz not found!"         "[[ -e ${JENKINS_ROOT}/home/userContent/${1}/coverage.xml.gz ]]"
    assertTrue "testcases.merged.xml.gz not found!" "[[ -e ${JENKINS_ROOT}/home/userContent/${1}/testcases.merged.xml.gz ]]"

    return 0
}

source lib/shunit2

exit 0

