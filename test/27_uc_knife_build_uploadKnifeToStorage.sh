#!/bin/bash

source lib/common.sh

initTempDirectory

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

    assertTrue "uploadKnifeToStorage"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustExistFile ${WORKSPACE}/workspace/lfs-knife.tar.gz
execute ncftpput -m -C mailarchiv.emea.nsn-net.net ${WORKSPACE}/workspace/lfs-knife.tar.gz /public/BernhardMinks/knife
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/shunit2

exit 0

