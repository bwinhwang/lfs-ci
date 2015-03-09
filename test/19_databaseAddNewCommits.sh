#!/bin/bash

source test/common.sh
initTempDirectory

source ${LFS_CI_ROOT}/lib/database.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    execute() {
        mockCommand "execute $@"
    }
    mustHaveNextCiLabelName() {
        mockCommand "mustHaveNextCiLabelName $@"
        return
    }
    getNextCiLabelName() {
        mockCommand "getNextCiLabelName $@"
        echo PS_LFS_OS_9999_88_7777
    }
    copyFileFromBuildDirectoryToWorkspace() {
        mockCommand "copyFileFromBuildDirectoryToWorkspace $@"
    }
    mockCommand() {
        echo $@ >> ${UT_MOCKED_COMMANDS}
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=jobName
    export BUILD_NUMBER=123

    return
}

tearDown() {
    return
}


testdatabaseAddNewCommits() {
    assertTrue "databaseAddNewCommits"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveNextCiLabelName
getNextCiLabelName
copyFileFromBuildDirectoryToWorkspace jobName 123 changelog.xml
execute -i ${LFS_CI_ROOT}/bin/newBuildEvent.pl --buildName=PS_LFS_OS_9999_88_7777 --action=new_svn_commits --changelog=${WORKSPACE}/changelog.xml
EOF

    assertExecutedCommands "${expect}"
}

source lib/shunit2

exit 0
