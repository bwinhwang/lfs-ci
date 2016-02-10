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
            jenkinsMasterServerHostName)         echo localhost ;;
            jenkinsMasterServerPath)             echo ${JENKINS_ROOT}/home ;;
            LFS_CI_coverage_data_path)           echo $(eval echo ${DATA_PATH}) ;;
            LFS_CI_coverage_data_files)          echo ${DATA_FILES} ;;
            LFS_CI_usercontent_data_path)        echo sonar/${subDir}/${targetType} ;;
            LFS_CI_is_fatal_data_files_missing)  echo ${isFatalDataFilesMissing} ;;
            LFS_CI_sonar_exclusions_src_path)    echo src-fsmddal/src ;;
            LFS_CI_sonar_additional_exclusions)  echo tools/** stubs/** lx2/DSDT/** **/*.h ;;
            LFS_CI_sonar_exclusions_lib_path)    echo src-fsmddal/build/${targetDir}/src/libFSMDDAL.a ;;
            *)                                   echo $1
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

    for TARGET in fsmr3 fsmr4 
    do
        export DATA_PATH=bld/bld-unittests-${TARGET}_fsmddal/results/__artifact
        export SONAR_DATA_PATH=$(getConfig LFS_CI_coverage_data_path)
        mkdir -p ${WORKSPACE}/${SONAR_DATA_PATH}
        touch ${WORKSPACE}/${SONAR_DATA_PATH}/coverage.xml.gz
        touch ${WORKSPACE}/${SONAR_DATA_PATH}/testcases.merged.xml.gz
    done

    for TARGET in FSMr3 FSMr4 
    do
        export DATA_PATH=src-test/src/testsuites/continousintegration/coverage/summary/__html/LCOV_${TARGET}
        export SONAR_DATA_PATH=$(getConfig LFS_CI_coverage_data_path)
        mkdir -p ${WORKSPACE}/${SONAR_DATA_PATH}
        touch ${WORKSPACE}/${SONAR_DATA_PATH}/coverage.xml.gz
    done

    # prepare workspace with libFSMDDAL.a for generation of exclusion lists
    mkdir -p ${WORKSPACE}/src-fsmddal/src
    mkdir -p ${WORKSPACE}/src-fsmddal/build/fct/src
    mkdir -p ${WORKSPACE}/src-fsmddal/build/fsm4_arm/src
    
    local n=0
    while (($n < 10))
    do 
        ((++n))
        touch ${WORKSPACE}/src-fsmddal/src/srcfile_${n}.c 
    done

    n=0
    while (($n < 6))
    do 
        ((++n))
        ar q ${WORKSPACE}/src-fsmddal/build/fct/src/libFSMDDAL.a ${WORKSPACE}/src-fsmddal/src/srcfile_${n}.c > /dev/null 2>&1
    done

    n=0
    while (($n < 8))
    do 
        ((++n))
        ar q ${WORKSPACE}/src-fsmddal/build/fsm4_arm/src/libFSMDDAL.a ${WORKSPACE}/src-fsmddal/src/srcfile_${n}.c > /dev/null 2>&1
    done


    return
}

tearDown() {
    rm -rf ${WORKSPACE}
    return 
}

test_UT_FSMr3() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3-UT_-_fsmr3_fsmddal
    export DATA_PATH=bld/bld-unittests-fsmr3_fsmddal/results/__artifact
    export DATA_FILES="coverage.xml.gz testcases.merged.xml.gz"
    assertTrue "usecase_LFS_COPY_SONAR_UT_DATA for FSMr3 failed!" "usecase_LFS_COPY_SONAR_UT_DATA"
    
    local targetType=$(getSubTaskNameFromJobName)
    local sonarPath=sonar/UT/${targetType}
    check_files_exist ${sonarPath}

    return
}

test_UT_FSMr4() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4-UT_-_fsmr4_fsmddal
    export DATA_PATH=bld/bld-unittests-fsmr4_fsmddal/results/__artifact
    export DATA_FILES="coverage.xml.gz testcases.merged.xml.gz"
    assertTrue "usecase_LFS_COPY_SONAR_UT_DATA for FSMr4 failed!" "usecase_LFS_COPY_SONAR_UT_DATA"

    local targetType=$(getSubTaskNameFromJobName)
    local sonarPath=sonar/UT/${targetType}
    check_files_exist ${sonarPath}

    return
}

test_SCT() {
    export JOB_NAME=LFS_CI_-_trunk_-_RegularTest
    export DATA_PATH='src-test/src/testsuites/continousintegration/coverage/summary/__html/LCOV_${targetType}'
    export DATA_FILES="coverage.xml.gz"
    assertTrue "usecase_LFS_COPY_SONAR_SCT_DATA failed!" "usecase_LFS_COPY_SONAR_SCT_DATA"
    
    local sonarPath=sonar/SCT/FSMr3
    check_files_exist ${sonarPath}
    local sonarPath=sonar/SCT/FSMr4
    check_files_exist ${sonarPath}

    return
}

test_no_files_not_fatal() {
    export DATA_PATH='this_path_does_not_exist'
    export DATA_FILES="coverage.xml.gz"
    export isFatalDataFilesMissing=
    assertTrue "usecase_LFS_COPY_SONAR_SCT_DATA failed!" "usecase_LFS_COPY_SONAR_SCT_DATA"

    return
}

test_no_files_fatal() {
    export DATA_PATH='this_path_does_not_exist'
    export DATA_FILES="coverage.xml.gz"
    export isFatalDataFilesMissing=1
    assertFalse "usecase_LFS_COPY_SONAR_SCT_DATA should have failed because of missing files!" "usecase_LFS_COPY_SONAR_SCT_DATA"

    return
}

test_generate_exclusionlist_fsmr3() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r3-UT_-_fsmr3_fsmddal
    export targetDir=fct
    assertTrue "_create_sonar_excludelist failed unexpectedly!" "_create_sonar_excludelist ${WORKSPACE}/FSM-r3-UT_exclusions.txt"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
**/src/srcfile_10.c ,\\
**/src/srcfile_7.c ,\\
**/src/srcfile_8.c ,\\
**/src/srcfile_9.c ,\\
**/src/tools/** ,\\
**/src/stubs/** ,\\
**/src/lx2/DSDT/** ,\\
**/src/**/*.h
EOF

    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/FSM-r3-UT_exclusions.txt)"

    return
}

test_generate_exclusionlist_fsmr4() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4-UT_-_fsmr4_fsmddal
    export targetDir=fsm4_arm
    assertTrue "_create_sonar_excludelist failed unexpectedly!" "_create_sonar_excludelist ${WORKSPACE}/FSM-r4-UT_exclusions.txt"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
**/src/srcfile_10.c ,\\
**/src/srcfile_9.c ,\\
**/src/tools/** ,\\
**/src/stubs/** ,\\
**/src/lx2/DSDT/** ,\\
**/src/**/*.h
EOF

    assertEquals "$(cat ${expect})" "$(cat ${WORKSPACE}/FSM-r4-UT_exclusions.txt)"

    return
}

check_files_exist() {
    # check that files exist
    for dataFile in $(getConfig LFS_CI_coverage_data_files)
    do
        assertTrue "${JENKINS_ROOT}/home/userContent/${1}/${dataFile} not found!"  "[[ -e ${JENKINS_ROOT}/home/userContent/${1}/${dataFile} ]]"
    done

    return 0
}

source lib/shunit2

exit 0

