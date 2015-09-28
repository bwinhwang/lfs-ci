#!/bin/bash

source test/common.sh
source lib/uc_release_prechecks.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            LFS_CI_uc_release_can_create_release_in_wft) echo ${UT_CAN_PRECHECK} ;;
            *) echo $1 ;;
        esac
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustBePreparedForReleaseTask() {
        mockedCommand "mustBePreparedForReleaseTask $@"
        export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME
        export LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL=PS_LFS_REL_BUILD_NAME
        export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME=PS_LFS_OS_OLD_BUILD_NAME
        export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL=PS_LFS_REL_OLD_BUILD_NAME
    }
    existsBaselineInWorkflowTool() {
        mockedCommand "existsBaselineInWorkflowTool $@"
        return ${UT_EXISTS_IN_WFT}
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Build
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_EXISTS_IN_WFT=0
    export UT_CAN_PRECHECK=1
    assertTrue "usecase_LFS_RELEASE_PRE_RELEASE_CHECKS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
getConfig LFS_CI_uc_release_can_create_release_in_wft
existsBaselineInWorkflowTool PS_LFS_OS_OLD_BUILD_NAME
existsBaselineInWorkflowTool PS_LFS_REL_OLD_BUILD_NAME
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_EXISTS_IN_WFT=0
    export UT_CAN_PRECHECK=
    assertTrue "usecase_LFS_RELEASE_PRE_RELEASE_CHECKS"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
getConfig LFS_CI_uc_release_can_create_release_in_wft
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
