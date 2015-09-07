#!/bin/bash

source test/common.sh

source lib/special_build.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    copyFileToArtifactDirectory() {
        mockedCommand "copyFileToArtifactDirectory $@"
    }

    getConfig() {
        echo $1
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}

    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_DEV_-_DEVELOPER_-_Build
    export UPSTREAM_BUILD=123

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "specialPkgpoolCollectArtifacts"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute tar cv --use-compress-program ${LFS_CI_ROOT}/bin/pigz --file ${WORKSPACE}/workspace/bld-pkgpool-artifacts.tar.gz --transform=s:^\pool/:pkgpool/: pool/
copyFileToArtifactDirectory ${WORKSPACE}/workspace/bld-pkgpool-artifacts.tar.gz LFS_DEV_-_DEVELOPER_-_Build 123
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
