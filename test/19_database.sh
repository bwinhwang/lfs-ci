#!/bin/bash

source lib/common.sh
initTempDirectory

source ${LFS_CI_ROOT}/lib/database.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    execute() {
        mockCommand "execute $@"
    }
    getLocationName() {
        mockCommand "getLocationName $@"
        echo trunk
    }
    mustHaveLocationName() {
        mockCommand "mustHaveLocationName $@"
        return
    }
    mustHaveNextCiLabelName() {
        mockCommand "mustHaveNextCiLabelName $@"
        return
    }
    getNextCiLabelName() {
        mockCommand "getNextCiLabelName $@"
        echo PS_LFS_OS_9999_88_7777
    }
            
    mockCommand() {
        echo $@ >> ${UT_MOCKED_COMMANDS}
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}

    export WORKSPACE=$(createTempDirectory)
    echo "src-bos foo 123456" > ${WORKSPACE}/revision_state.txt

    return
}

tearDown() {
    return
}

testDatabaseEventBuildStarted_ok() {
    assertTrue "databaseEventBuildStarted"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getLocationName
mustHaveLocationName
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n PS_LFS_OS_9999_88_7777 -b trunk -r 123456 -a build_started
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}


testDatabaseEventBuildFinished_ok() {
    assertTrue "databaseEventBuildFinished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n PS_LFS_OS_9999_88_7777 -a build_finished
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

testDatabaseEventBuildFailed_ok() {
    assertTrue "databaseEventBuildFinished 0"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n PS_LFS_OS_9999_88_7777 -a build_finished
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

testDatabaseEventBuildFailed_failed() {
    assertTrue "databaseEventBuildFailed 1"
    assertEquals "" "$(cat ${UT_MOCKED_COMMANDS})"
}

testdatabaseEventReleaseStarted() {
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_9999_88_7777
    assertTrue "databaseEventReleaseStarted"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n PS_LFS_OS_9999_88_7777 -a release_started
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

testdatabaseEventReleaseFinished() {
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_9999_88_7777
    assertTrue "databaseEventReleaseFinished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl -n PS_LFS_OS_9999_88_7777 -a release_finished
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

source lib/shunit2

exit 0
