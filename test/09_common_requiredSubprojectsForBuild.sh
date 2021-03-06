#!/bin/bash

source test/common.sh

source lib/createWorkspace.sh

export UT_BUILD_SRC_LIST=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    exit_handler() {
        echo exit
    }
    execute() {
        mockedCommand "execute $@"
        cat ${UT_BUILD_SRC_LIST}
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
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

testLatestRevisionFromRevisionStateFile_withoutProblem() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/

    echo "src-abc" > ${UT_BUILD_SRC_LIST}

    assertTrue "requiredSubprojectsForBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_UC_build_onlySourceDirectories
getConfig LFS_CI_UC_build_subsystem_to_build
execute -n build -W "${WORKSPACE}/workspace" -C src-project src-list_LFS_FSM-r4
getConfig LFS_CI_UC_build_additionalSourceDirectories
EOF
    assertExecutedCommands ${expect}

    # test for correct value
    local src=$(requiredSubprojectsForBuild 2>/dev/null)
    assertEquals "got expected revision" "src-abc" "${src}" 

}

testLatestRevisionFromRevisionStateFile_withoutProblem2() {
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace/

    echo "src-abc src-foo src-bar" > ${UT_BUILD_SRC_LIST}

    assertTrue "requiredSubprojectsForBuild"
    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_CI_UC_build_onlySourceDirectories
getConfig LFS_CI_UC_build_subsystem_to_build
execute -n build -W "${WORKSPACE}/workspace" -C src-project src-list_LFS_FSM-r4
getConfig LFS_CI_UC_build_additionalSourceDirectories
EOF
    assertExecutedCommands ${expect}

    # test for correct value
    local src=$(requiredSubprojectsForBuild 2>/dev/null)
    assertEquals "got expected revision" "src-abc src-foo src-bar" "${src}" 

}
source lib/shunit2

exit 0
