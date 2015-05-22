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
    assertTrue "applyKnifePatches"
    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute tar -xvz -C ${WORKSPACE}/workspace -f ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.tar.gz
execute -i patch -p0 -d ${WORKSPACE}/workspace
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    assertTrue "applyKnifePatches"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}

    return
}


test3() {
    export WORKSPACE=$(createTempDirectory)
    export KNIFE_LFS_BASELINE=PS_LFS_OS_2014_01_0001
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build

    mkdir -p ${WORKSPACE}/workspace/bld/bld-knife-input/
    touch ${WORKSPACE}/workspace/bld/bld-knife-input/lfs.patch

    assertTrue "applyKnifePatches"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute -i patch -p0 -d ${WORKSPACE}/workspace
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/shunit2

exit 0

