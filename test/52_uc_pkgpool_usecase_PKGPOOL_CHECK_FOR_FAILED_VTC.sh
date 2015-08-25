#!/bin/bash

source test/common.sh

source lib/uc_pkgpool.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        if [[ ${UT_COUNTER} == 1 ]] ; then
            echo line
        fi
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release
        echo buildName > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/label
    }
    mustExistFile() {
        mockedCommand "mustExistFile $@"
    }
        

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=PKGPOOL_CI_-_trunk_-_Build
    export BUILD_NUMBER=123
    mkdir ${WORKSPACE}/src/
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

test1() {
    export UT_COUNTER=0

    assertFalse "failed" "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
mustExistFile /build/home/SC_LFS/pkgpool/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
execute -n tar tvf /build/home/SC_LFS/pkgpool/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
EOF
    assertExecutedCommands ${expect}

    return
}


test2() {
    export UT_COUNTER=1

    assertTrue "ok" "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
mustExistFile /build/home/SC_LFS/pkgpool/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
execute -n tar tvf /build/home/SC_LFS/pkgpool/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
