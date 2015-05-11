#!/bin/bash

source test/common.sh

source lib/uc_knife_build.sh

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
    getConfig() {
        mockedCommand "getConfig $@"
        echo "server:upload/"
    }
    s3PutFile() {
        mockedCommand "s3PutFile $@"
    }
    s3SetAccessPublic() {
        mockedCommand "s3SetAccessPublic $@"
    }
}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
}
tearDown() {
    true 
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export KNIFE_LFS_BASELINE=PS_LFS_OS_2014_01_0001
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build

    assertTrue "uploadKnifeToStorage /path/to/file"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustExistFile /path/to/file
getConfig LFS_CI_upload_server
s3PutFile /path/to/file server:upload/
s3SetAccessPublic server:upload//file
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

