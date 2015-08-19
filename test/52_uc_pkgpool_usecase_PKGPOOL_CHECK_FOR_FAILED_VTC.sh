#!/bin/bash

source test/common.sh

source lib/uc_pkgpool.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        return ${UT_GREP_FAILED}
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
    }
        

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=PKGPOOL_CI_-_trunk_-_Build
    export BUILD_NUMBER=123
    mkdir ${WORKSPACE}/src/
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

test1() {
    export UT_GREP_FAILED=0

    assertFalse "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
execute -i grep --silent LVTC FSMR4 BUILD FAILED ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
execute -i grep -A 100 -B 100 LVTC FSMR4 BUILD FAILED ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
EOF
    assertExecutedCommands ${expect}

    return
}


test2() {
    export UT_GREP_FAILED=1

    assertTrue "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
execute -i grep --silent LVTC FSMR4 BUILD FAILED ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
