#!/bin/bash

source test/common.sh

source lib/special_build.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        if [[ $1 = mkdir ]] ; then
            shift
            mkdir $@
        fi
        if [[ $2 = lsdiff ]] ; then
            shift
            $@
        fi
    }
    getConfig() {
        echo $1
    }
    gitCheckout() {
        mockedCommand "gitCheckout $@"
    }
    gitReset() {
        mockedCommand "gitReset $@"
    }
    gitClone() {
        mockedCommand "gitClone $@"
        mkdir -p ${WORKSPACE}/src
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-dev-input/
        cp ${LFS_CI_ROOT}/test/data/28_uc_knife_build_applyKnifePatches.pkgpool.patch \
            ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
    }
    copyAndExtractBuildArtifactsFromProject() {
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        echo trunk > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/location
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}

    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_DEV_-_DEVELOPER_-_Build
    export UPSTREAM_BUILD=123
    export LFS_CI_GLOBAL_BRANCH_NAME=trunk
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "specialPkgpoolPrepareBuild dev"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace
copyArtifactsToWorkspace LFS_DEV_-_DEVELOPER_-_Build 123
execute rm -rf ${WORKSPACE}/src
gitClone PKGPOOL_git_repos_url ${WORKSPACE}/src
gitCheckout 
gitReset --hard
execute -n lsdiff ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute git submodule update src/fsmddal
execute -n filterdiff -i src/fsmddal/Dependencies ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/workspace
execute git submodule update src/fsmpsl
execute -n filterdiff -i src/fsmpsl/Buildfile ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/workspace
execute git submodule update src/fsmpsl
execute -n filterdiff -i src/fsmpsl/Dependencies ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/workspace
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
