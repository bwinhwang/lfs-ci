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
    execute() {
        mockedCommand "execute $@"
        if [[ $2 = sed ]] ; then
            echo PKGPOOL_FOO
        fi
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
    mustHaveCleanWorkspace() {
        mkdir -p ${WORKSPACE}/workspace
    }
    getConfig() {
        echo $1 
    }
    gitStatus() {
        mockedCommand "gitStatus $@"
        if [[ -e ${UT_GIT_STATUS_1} ]] ; then
            echo "aa src/abc"
            rm -rf ${UT_GIT_STATUS_1}
        elif [[ -e ${UT_GIT_STATUS_2} ]] ; then
            echo "aa src/abc"
            rm -rf ${UT_GIT_STATUS_2}
        fi
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
    assertTrue "_preparePkgpoolWorkspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/src/src
gitReset --hard
execute ./bootstrap
gitStatus -s
gitStatus -s
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_GIT_STATUS_1=$(createTempFile)
    export UT_GIT_STATUS_2=
    assertTrue "_preparePkgpoolWorkspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/src/src
gitReset --hard
execute ./bootstrap
gitStatus -s
execute git submodule update src/abc
gitStatus -s
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    export UT_GIT_STATUS_1=$(createTempFile)
    export UT_GIT_STATUS_2=$(createTempFile)
    assertTrue "_preparePkgpoolWorkspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute rm -rf ${WORKSPACE}/src/src
gitReset --hard
execute ./bootstrap
gitStatus -s
execute git submodule update src/abc
gitStatus -s
execute rm -rf ${WORKSPACE}/src/src
gitReset --hard
execute ./bootstrap
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
