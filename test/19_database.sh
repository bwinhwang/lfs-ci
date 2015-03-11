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
    runOnMaster() {
        mockCommand "runOnMaster $@"
        echo src-project http-url 123456
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
    assertTrue "databaseEventBuildStarted"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getLocationName
mustHaveLocationName
getLocationName
runOnMaster cat /var/fpwork/psulm/lfs-jenkins/home/jobs/LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd/builds/123/revisionstate.xml
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=build_started --jobName=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd --buildNumber=123 --targetName=--revision=123456 --targetType=--branchName=trunk
EOF
    assertExecutedCommands ${expect}
}


testDatabaseEventSubBuildFinished_ok() {
    assertTrue "databaseEventSubBuildFinished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=subbuild_finished --jobName=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd --buildNumber=123 --targetName=FSM-r2 --targetType=fcmd
EOF

    assertExecutedCommands ${expect}
}

testDatabaseEventSubBuildFailed_ok() {
    assertTrue "databaseEventSubBuildFinished 0"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=subbuild_finished --jobName=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd --buildNumber=123 --targetName=FSM-r2 --targetType=fcmd
EOF

    assertExecutedCommands ${expect}
}

testdatabaseEventReleaseStarted() {
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_9999_88_7777
    assertTrue "databaseEventReleaseStarted"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=release_started --jobName=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd --buildNumber=123 --targetName=FSM-r2 --targetType=fcmd
EOF

    assertExecutedCommands ${expect}
}

testdatabaseEventReleaseFinished() {
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_9999_88_7777
    assertTrue "databaseEventReleaseFinished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newEvent --buildName=PS_LFS_OS_9999_88_7777 --action=release_finished --jobName=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd --buildNumber=123 --targetName=FSM-r2 --targetType=fcmd
EOF

    assertExecutedCommands ${expect}
}

testDatabaseTestResults() {
    assertTrue "databaseTestResults PS_LFS_OS_9999_88_7777 testSuite targetName targetType resultFile"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newTestResults --action=new_test_result --buildName=PS_LFS_OS_9999_88_7777 --resultFile=resultFile --testSuiteName=testSuite --targetName=targetName --targetType=targetType
EOF

    assertExecutedCommands ${expect}
}

source lib/shunit2

exit 0
