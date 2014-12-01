#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/uc_release.sh

export UNITTEST_COMMAND=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UNITTEST_COMMAND}
    }
    exit_handler() {
        echo exit
    }
    date() {
        mockedCommand "date $@"
        echo date
    }
    execute() {
        mockedCommand "execute $@"
        if [[ ${UT_EXECUTE_FAILS} ]] ; then
            return 1
        fi
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

testCreateReleaseInStatisticDatabase_withoutProblem() {

    export JOB_NAME=LFS_Prod_-_trunk_-_Release_-_summary
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=A
    export UT_EXECUTE_FAILS=

    assertTrue "createReleaseInStatisticDatabase"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
date +%Y-%m-%d %H-%M-%S
date +%Y-%m-%d %H:%M:%S.%N %Z
date +%s.%N
execute /home/demx2fk3/lfs-ci/bin/createReleaseInDatabase.pl -n A -b pronb-developer -d date
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"
}

testCreateReleaseInStatisticDatabase_withProblem() {

    export JOB_NAME=LFS_Prod_-_trunk_-_Release_-_summary
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=B
    export UT_EXECUTE_FAILS=1

    assertFalse "createReleaseInStatisticDatabase"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
date +%Y-%m-%d %H-%M-%S
date +%Y-%m-%d %H:%M:%S.%N %Z
date +%s.%N
execute /home/demx2fk3/lfs-ci/bin/createReleaseInDatabase.pl -n B -b pronb-developer -d date
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UNITTEST_COMMAND})"
}

source lib/shunit2

exit 0
