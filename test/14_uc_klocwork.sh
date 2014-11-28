#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/uc_klocwork.sh

export UNITTEST_COMMAND=$(createTempFile)
export UT_BUILD_SRC_LIST=$(createTempFile)

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
    }
    createOrUpdateWorkspace() {
        mockedCommand "createOrUpdateWorkspace $@"
    }

    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_uc_klocwork_project_name)
                echo PS_LFS_DDAL
                ;;
        esac
    }

    svnExport() {
        mockedCommand "svnExport $@"
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

testUsecaseKlocwork_part1() {
    # export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r4_-_fsm4_axm
    export WORKSPACE=$(createTempDirectory)
    export BUILD_ID=1234

    assertTrue "ci_job_klocwork_build"
    cat ${UNITTEST_COMMAND}

#     local expect=$(createTempFile)
#     cat <<EOF > ${expect}
# EOF
#     assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"

}

source lib/shunit2

exit 0
