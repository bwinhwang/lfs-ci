#!/bin/bash

source test/common.sh

source lib/uc_pkgpool.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    gitReset() {
        mockedCommand "gitReset $@"
    }
    gitTagAndPushToOrigin() {
        mockedCommand "gitTagAndPushToOrigin $@"
    }
    gitDescribe() {
        mockedCommand "gitDescribe $@"
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    execute() {
        mockedCommand "execute $@"
        if [[ $2 = sed ]] ; then
            echo PKGPOOL_FOO
        fi
    }
    mustHaveCleanWorkspace() {
        mkdir -p ${WORKSPACE}/workspace
    }
    createTempFile() {
        echo "TempFile"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=PKGPOOL_CI_-_trunk_-_Build
    export BUILD_NUMBER=123

    mkdir ${WORKSPACE}/src/

    assertTrue "usecase_PKGPOOL_BUILD"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/src/src
gitReset --hard
execute ./bootstrap
execute ${WORKSPACE}/src/build -j100 --pkgpool=/build/home/psulm/SC_LFS/pkgpool --prepopulate --release=BM_PKGPOOL_
execute -n sed -ne s,^release \([^ ]*\) complete$,\1,p TempFile
gitDescribe --abbrev=0
gitTagAndPushToOrigin 
setBuildDescription PKGPOOL_CI_-_trunk_-_Build 123 PKGPOOL_FOO
execute touch /build/home/SC_LFS/pkgpool/.hashpool
execute sed -ne s|^src [^ ]* \(.*\)$|PS_LFS_PKG = \1|p ${WORKSPACE}/workspace/pool/*.meta
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
