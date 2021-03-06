#!/bin/bash

source test/common.sh

source ${LFS_CI_ROOT}/lib/database.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    execute() {
        mockCommand "execute $@"
    }
    getLocationName() {
        mockCommand "getLocationName $@"
        echo pronb-developer
    }
    getBranchName() {
        mockCommand "getBranchName $@"
        echo trunk
    }
    mustHaveLocationName() {
        mockCommand "mustHaveLocationName $@"
        return
    }
    mustHaveBranchName() {
        mockCommand "mustHaveBranchName $@"
        return
    }
    mustHaveNextCiLabelName() {
        return
    }
    getNextCiLabelName() {
        echo PS_LFS_OS_9999_88_7777
    }
    runOnMaster() {
        mockCommand "runOnMaster $@"
        echo src-project http-url 123456
    }
    getBuildDirectoryOnMaster() {
        mockCommand "getBuildDirectoryOnMaster $@"
        echo /path/to/build/job/number
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

    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    export BUILD_NUMBER=123

    return
}

tearDown() {
    return
}

testDatabaseEventBuildStarted_ok() {
    assertTrue "eventBuildStarted"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getBranchName
mustHaveBranchName
getBuildDirectoryOnMaster LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd 123
runOnMaster cat /path/to/build/job/number/revisionstate.xml
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=build_started --jobName=${JOB_NAME} --buildNumber=123 --productName=LFS --taskName=build --revision=123456 --branchName=trunk
EOF
    assertExecutedCommands ${expect}
}


testDatabaseEventSubBuildFinished_ok() {
    export JOB_NAME=LFS_CI_-_trunk_-_Test_-_FSM-r3_-_FSMF
    assertTrue "storeEvent subbuild_finished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=subbuild_finished --jobName=${JOB_NAME} --buildNumber=123 --productName=LFS --taskName=test
EOF

    assertExecutedCommands ${expect}
}

testDatabaseEventSubBuildFailed_ok() {
    export JOB_NAME=LFS_CI_-_trunk_-_Test_-_FSM-r3_-_FSMF
    assertTrue "storeEvent subbuild_finished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=subbuild_finished --jobName=${JOB_NAME} --buildNumber=123 --productName=LFS --taskName=test
EOF

    assertExecutedCommands ${expect}
}

testdatabaseEventReleaseStarted() {
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_9999_88_7777
    export JOB_NAME=LFS_CI_-_trunk_-_Test_-_FSM-r3_-_FSMF
    assertTrue "storeEvent release_started"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=release_started --jobName=${JOB_NAME} --buildNumber=123 --productName=LFS --taskName=test
EOF

    assertExecutedCommands ${expect}
}

testdatabaseEventReleaseFinished() {
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_9999_88_7777
    export JOB_NAME=LFS_CI_-_trunk_-_Test_-_FSM-r3_-_FSMF
    assertTrue "storeEvent release_finished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=release_finished --jobName=${JOB_NAME} --buildNumber=123 --productName=LFS --taskName=test
EOF

    assertExecutedCommands ${expect}
}

testDatabaseTestResults() {
    assertTrue "databaseTestResults PS_LFS_OS_9999_88_7777 testSuite targetName targetType resultFile jobName buildNumber"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/newTestResults --buildName=PS_LFS_OS_9999_88_7777 --resultFile=resultFile --testSuiteName=testSuite --targetName=targetName --targetType=targetType --jobName=jobName --buildNumber=buildNumber
EOF

    assertExecutedCommands ${expect}
}

testDatabaseTestCaseResults() {
    assertTrue "databaseTestCaseResults PS_LFS_OS_9999_88_7777 testSuite targetName targetType resultFile jobName buildNumber"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/bin/newTestCaseResults --buildName=PS_LFS_OS_9999_88_7777 --resultFile=resultFile --testSuiteName=testSuite --targetName=targetName --targetType=targetType --jobName=jobName --buildNumber=buildNumber
EOF

    assertExecutedCommands ${expect}
}

source lib/shunit2

exit 0
