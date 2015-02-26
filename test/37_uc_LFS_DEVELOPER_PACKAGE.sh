#!/bin/bash

source test/common.sh

source lib/uc_developer_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    ci_job_package() {
        mockedCommand "ci_job_package $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_DEVELOPER_PACKAGE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
ci_job_package 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
