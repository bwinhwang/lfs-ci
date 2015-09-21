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
        local cnt=$(cat ${UT_TMPDIR}/.cnt)
        cnt=$((cnt + 1 ))
        echo ${cnt} > ${UT_TMPDIR}/.cnt
        touch ${UT_TMPDIR}/tmp.${cnt}
        echo ${UT_TMPDIR}/tmp.${cnt}
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
    export UT_TMPDIR=$(createTempDirectory)
    echo 0 > ${UT_TMPDIR}/.cnt
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    rm -rf ${UT_TMPDIR}
    return
}

test1() {
    assertTrue "usecase_PKGPOOL_BUILD"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_preparePkgpoolWorkspace 
execute -l ${UT_TMPDIR}/tmp.2 ${WORKSPACE}/src/build PKGPOOL_additional_build_parameters
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
execute cp ${UT_TMPDIR}/tmp.2 ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
execute cp -a ${WORKSPACE}/workspace/logs ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
_tagPkgpool ${UT_TMPDIR}/tmp.2
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_CAN_RELEASE=

    assertTrue "usecase_PKGPOOL_BUILD"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
_preparePkgpoolWorkspace 
execute -l ${UT_TMPDIR}/tmp.2 ${WORKSPACE}/src/build PKGPOOL_additional_build_parameters
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
execute cp ${UT_TMPDIR}/tmp.2 ${WORKSPACE}/workspace/bld/bld-pkgpool-release/build.log
execute cp -a ${WORKSPACE}/workspace/logs ${WORKSPACE}/workspace/bld/bld-pkgpool-release/
_tagPkgpool ${UT_TMPDIR}/tmp.2
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
