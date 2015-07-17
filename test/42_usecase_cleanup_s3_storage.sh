#!/bin/bash

source test/common.sh

source lib/uc_admin_cleanup_s3.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        shift
        "$@"
    }
    s3List() {
        mockedCommand "s3List $@"
        cat ${UT_S3LIST_MOCK}
    }
    s3RemoveFile() {
        mockedCommand "s3RemoveFile $@"
    }
    return
}

setUp() {
    export JOB_NAME=Admin_-_cleanupS3Storage_-_lfs-knives
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_S3LIST_MOCK=$(createTempFile)
    assertTrue "usecase_ADMIN_CLEANUP_S3"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n date +%Y-%m-%d --date=0 days ago
execute -n date +%Y-%m-%d --date=1 days ago
execute -n date +%Y-%m-%d --date=2 days ago
execute -n date +%Y-%m-%d --date=3 days ago
s3List s3://lfs-knives
EOF
    assertExecutedCommands ${expect}

    return
}
test2() {
    export UT_S3LIST_MOCK=$(createTempFile)
    echo "$(date +%Y-%m-%d --date="3 days ago") A A s3://lfs-knives/A" >> ${UT_S3LIST_MOCK}
    echo "$(date +%Y-%m-%d --date="4 days ago") B B s3://lfs-knives/B" >> ${UT_S3LIST_MOCK}
    echo "$(date +%Y-%m-%d --date="6 days ago") C C s3://lfs-knives/C" >> ${UT_S3LIST_MOCK}

    assertTrue "usecase_ADMIN_CLEANUP_S3"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute -n date +%Y-%m-%d --date=0 days ago
execute -n date +%Y-%m-%d --date=1 days ago
execute -n date +%Y-%m-%d --date=2 days ago
execute -n date +%Y-%m-%d --date=3 days ago
s3List s3://lfs-knives
s3RemoveFile B s3://lfs-knives
s3RemoveFile C s3://lfs-knives
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
