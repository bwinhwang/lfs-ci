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
        if [[ $@ =~ grep ]] ; then
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
    mustHaveLocationForSpecialBuild() {
        mockedCommand "mustHaveLocationForSpecialBuild $@"
    }
    getLocationName() {
        mockedCommand "getLocationName $@"
        echo pronb-developer
    }
    mustHaveLocationName() {
        return
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}

    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_DEV_-_DEVELOPER_-_Build
    export UPSTREAM_BUILD=123
    export LFS_CI_GLOBAL_BRANCH_NAME=trunk

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
mustHaveLocationForSpecialBuild 
getLocationName 
copyArtifactsToWorkspace LFS_DEV_-_DEVELOPER_-_Build 123
execute rm -rf ${WORKSPACE}/src
gitClone PKGPOOL_git_repos_url ${WORKSPACE}/src
gitCheckout 
gitReset --hard
execute ./bootstrap
execute rm -rf ${WORKSPACE}/.alreadyUpdated
execute -n lsdiff ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute -i grep -s -e ^src/fsmddal$ ${WORKSPACE}/.alreadyUpdated
execute git submodule update src/fsmddal
execute -n filterdiff -i src/fsmddal/Dependencies ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/src
execute git add -f .
execute git commit -m patch_commit
execute -i grep -s -e ^src/fsmpsl$ ${WORKSPACE}/.alreadyUpdated
execute git submodule update src/fsmpsl
execute -n filterdiff -i src/fsmpsl/Buildfile ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/src
execute git add -f .
execute git commit -m patch_commit
execute -i grep -s -e ^src/fsmpsl$ ${WORKSPACE}/.alreadyUpdated
execute -n filterdiff -i src/fsmpsl/Dependencies ${WORKSPACE}/workspace/bld/bld-dev-input/lfs.patch
execute patch -p0 -d ${WORKSPACE}/src
execute git add -f .
execute git commit -m patch_commit
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
