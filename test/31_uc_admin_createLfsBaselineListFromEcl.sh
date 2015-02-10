#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/uc_admin.sh

export UNITTEST_COMMAND=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UNITTEST_COMMAND}
    }
    execute() {
        mockedCommand "execute $@"
        sleep 1
    }
    createTempFile() {
        echo /path/to/tmp
    }

    return
}

setUp() {
    cp -f /dev/null ${UNITTEST_COMMAND}
}

tearDown() {
    rm -rf ${UNITTEST_COMMAND}
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace/.build_workdir

    assertTrue "createLfsBaselineListFromEcl"

    local expect=$(mktemp)
cat <<EOF > ${expect}
execute -n grep -e PS_LFS_OS -e PS_LFS_REL */ECL_BASE/ECL
execute -n cut -d= -f2
execute -n cat /path/to/tmp /path/to/tmp
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"
    rm -rf ${expect}
}

source lib/shunit2

exit 0
