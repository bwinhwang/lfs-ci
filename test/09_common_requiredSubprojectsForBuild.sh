#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/createWorkspace.sh

export UNITTEST_COMMAND=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UNITTEST_COMMAND}
    }
    exit_handler() {
        echo exit
    }
    mustHaveValue() {
        mockedCommand "mustHaveValue $@"
        return
    }
    execute() {
        mockedCommand "execute $@"
        echo ${UT_BUILD_SRC_LIST}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_UC_build_onlySourceDirectories)
                echo ${UT_CONFIG_ONLY_SOURCE}
            ;;
            LFS_CI_UC_build_additionalSourceDirectories)
                echo ${UT_CONFIG_ADD_SOURCE}
            ;;
            LFS_CI_UC_build_subsystem_to_build)
                echo src-project
            ;;
        esac
    }

    return
}

setUp() {
    cp -f /dev/null ${UNITTEST_COMMAND}
}

tearDown() {
    rm -rf ${UNITTEST_COMMAND}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

testLatestRevisionFromRevisionStateFile_withoutProblem() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/

    export UT_BUILD_SRC_LIST="src-abc"

    assertTrue "requiredSubprojectsForBuild"
    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveValue LFS product name
mustHaveValue FSM-r4 sub task name
getConfig LFS_CI_UC_build_onlySourceDirectories
getConfig LFS_CI_UC_build_subsystem_to_build
mustHaveValue src-project src directory
execute -n build -W "${WORKSPACE}/workspace" -C src-project src-list_LFS_FSM-r4
mustHaveValue src-abc no build targets configured
getConfig LFS_CI_UC_build_additionalSourceDirectories
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

    # test for correct value
    local src=$(requiredSubprojectsForBuild)
    assertEquals "got expected revision" "src-abc" "${src}" 

}

testLatestRevisionFromRevisionStateFile_withoutProblem() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/

    export UT_BUILD_SRC_LIST="src-abc"
    export UT_BUILD_SRC_LIST="src-abc src-foo src-bar"

    assertTrue "requiredSubprojectsForBuild"
    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveValue LFS product name
mustHaveValue FSM-r4 sub task name
getConfig LFS_CI_UC_build_onlySourceDirectories
getConfig LFS_CI_UC_build_subsystem_to_build
mustHaveValue src-project src directory
execute -n build -W "${WORKSPACE}/workspace" -C src-project src-list_LFS_FSM-r4
mustHaveValue src-abc no build targets configured
getConfig LFS_CI_UC_build_additionalSourceDirectories
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

    # test for correct value
    local src=$(requiredSubprojectsForBuild)
    assertEquals "got expected revision" "src-abc src-foo src-bar" "${src}" 

}
source lib/shunit2

exit 0
