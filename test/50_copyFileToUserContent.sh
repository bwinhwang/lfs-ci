#!/bin/bash

source test/common.sh

source lib/artifacts.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    mustExistFile() {
        mockedCommand "mustExistFile $@"
    }
}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    export JOB_NAME=LFS_CI_-_trunk_-_Build
}
tearDown() {
    true 
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123

    local fileName=coverage.gz
    touch ${WORKSPACE}/${fileName}

    assertTrue "copyFileToUserContentDirectory ${WORKSPACE}/${fileName} sonar/FSM-r3"

    local expect=$(createTempFile)
    local serverName=$(getConfig jenkinsMasterServerHostName)
    local jenkinsMasterServerPath=$(getConfig jenkinsMasterServerPath)
    local pathOnServer=${jenkinsMasterServerPath}/userContent/sonar/FSM-r3

cat <<EOF > ${expect}
execute -r 10 ssh ${serverName} mkdir -p ${pathOnServer}
execute -r 10 rsync --archive --verbose --rsh=ssh -P ${WORKSPACE}/${fileName} ${serverName}:${pathOnServer}/${fileName}
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0

