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
        if [[ $2 == lsdiff ]] ; then
            shift
            $@
        fi                
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
    export WORKSPACE=$(createTempDirectory)
    export KNIFE_LFS_BASELINE=PS_LFS_OS_2014_01_0001
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build

    mkdir -p ${WORKSPACE}/workspace/src-fsmpsl
    touch    ${WORKSPACE}/workspace/src-fsmpsl/Buildfile
    touch    ${WORKSPACE}/workspace/src-fsmpsl/Dependencies
    mkdir -p ${WORKSPACE}/workspace/src-rfs
    touch    ${WORKSPACE}/workspace/src-rfs/Buildfile
    touch    ${WORKSPACE}/workspace/src-rfs/Dependencies
    mkdir -p ${WORKSPACE}/workspace/src-psl
    touch    ${WORKSPACE}/workspace/src-psl/Buildfile
    touch    ${WORKSPACE}/workspace/src-psl/Dependencies

    mkdir -p ${WORKSPACE}/workspace/bld/bld-knife-input/
    cp ${LFS_CI_ROOT}/test/data/28_uc_knife_build_applyKnifePatches.patch \
             ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
    touch    ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.tar.gz

}
tearDown() {
    true 
}

test1() {
    rm -rf ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
    assertTrue "applyKnifePatches"
    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute tar -xvz -C ${WORKSPACE}/workspace -f ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.tar.gz
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    rm -rf ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.tar.gz
    assertTrue "applyKnifePatches"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute -n lsdiff ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
execute -n filterdiff -i src-fsmpsl/Buildfile ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/workspace
execute -n filterdiff -i src-fsmpsl/Dependencies ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/workspace
execute -n filterdiff -i src-rfs/Buildfile ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/workspace
execute -n filterdiff -i src-rfs/Dependencies ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/workspace
EOF
    assertExecutedCommands ${expect}

    return
}


test3() {
    # no files to patch
    rm -rf ${WORKSPACE}/workspace/src-*
    rm -rf ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.tar.gz
    assertTrue "applyKnifePatches"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute -n lsdiff ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

