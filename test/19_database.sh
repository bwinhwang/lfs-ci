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

    return
}

tearDown() {
    return
}

testDatabaseEventBuildStarted_ok() {
    export JOB_NAME=Build_Job
    export BUILD_NUMBER=123

    assertTrue "databaseEventBuildStarted"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getLocationName
mustHaveLocationName
getLocationName
runOnMaster cat /var/fpwork/psulm/lfs-jenkins/home/jobs/Build_Job/builds/123/revisionstate.xml
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=PS_LFS_OS_9999_88_7777 --branchName=trunk --revision=123456 --action=build_started
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}


testDatabaseEventBuildFinished_ok() {
    export JOB_NAME=Build_Job
    export BUILD_NUMBER=123

    assertTrue "databaseEventBuildFinished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=PS_LFS_OS_9999_88_7777 --action=build_finished
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

testDatabaseEventBuildFailed_ok() {
    assertTrue "databaseEventBuildFinished 0"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=PS_LFS_OS_9999_88_7777 --action=build_finished
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
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=PS_LFS_OS_9999_88_7777 --action=release_started
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

testdatabaseEventReleaseFinished() {
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_9999_88_7777
    assertTrue "databaseEventReleaseFinished"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=PS_LFS_OS_9999_88_7777 --action=release_finished
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

testDatabaseTestResults() {
    assertTrue "databaseTestResults PS_LFS_OS_9999_88_7777 testSuite targetName targetType resultFile"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --action=new_test_result --buildName=PS_LFS_OS_9999_88_7777 --resultFile=resultFile --testSuiteName=testSuite --targetName=targetName --targetType=targetType
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"
}

source lib/shunit2

exit 0
