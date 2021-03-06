#!/bin/bash

source test/common.sh

source lib/amazons3.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-ci.cfg
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    local file=$(createTempFile)
    assertTrue "s3PutFile ${file} bucket"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/lib/contrib/s3cmd/s3cmd -c ${LFS_CI_ROOT}/etc/system/dot_s3cfg put ${file} bucket
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    local file=$(createTempFile)
    assertTrue "s3RemoveFile s3://bucket/${file}"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/lib/contrib/s3cmd/s3cmd -c ${LFS_CI_ROOT}/etc/system/dot_s3cfg rm s3://bucket/${file}
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    local file=$(createTempFile)
    assertTrue "s3SetAccessPublic s3://bucket/file"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute ${LFS_CI_ROOT}/lib/contrib/s3cmd/s3cmd -c ${LFS_CI_ROOT}/etc/system/dot_s3cfg --acl-public setacl s3://bucket/file
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
