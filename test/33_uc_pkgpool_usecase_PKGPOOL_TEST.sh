#!/bin/bash

source lib/common.sh
initTempDirectory

source lib/uc_pkgpool.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    mustHaveCleanWorkspace() {
        mockedCommand "mustHaveCleanWorkspace $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=PKGPOOL_CI_-_trunk_-_Build
    export BUILD_NUMBER=1
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Build
    export UPSTREAM_BUILD=1

    # assertTrue "ci_job_klocwork_build"
    assertTrue "usecase_PKGPOOL_TEST"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveCleanWorkspace 
copyArtifactsToWorkspace PKGPOOL_CI_-_trunk_-_Build 1 pkgpool
createArtifactArchive 
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/shunit2

exit 0
