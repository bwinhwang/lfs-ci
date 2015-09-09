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
    createTempFile() {
        echo "TempFile"
    }
    getConfig() {
        echo $1 
    }
    _preparePkgpoolWorkspace() {
        mockedCommand "_preparePkgpoolWorkspace $@"
    }
    _tagPkgpool() {
        mockedCommand "_tagPkgpool $@"
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
    assertTrue "usecase_PKGPOOL_BUILD"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_preparePkgpoolWorkspace 
execute -l TempFile ${WORKSPACE}/src/build PKGPOOL_additional_build_parameters
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
execute cp TempFile ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
execute cp -a ${WORKSPACE}/workspace/logs ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
_tagPkgpool TempFile
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}


source lib/shunit2

exit 0
