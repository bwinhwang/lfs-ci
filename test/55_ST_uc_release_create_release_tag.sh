#!/bin/bash

source test/common.sh
# source lib/uc_release.sh
source lib/uc_release_create_rel_tag.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_UC_package_copy_to_share_real_location) echo ${UT_CI_LFS_SHARE} ;;
            LFS_PROD_uc_release_based_on) echo PS_LFS_OS_2015_07_0001 ;;
            LFS_PROD_svn_delivery_release_repos_url) echo file://${UT_SVN_ROOT}/isource/svnroot/BTS_D_SC_LFS_2015_08/ ;;
            LFS_uc_release_create_release_tag_sdk_external_line) echo /isource/svnroot/BTS_D_SC_LFS_2015_08/sdk sdk;;
            LFS_PROD_svn_delivery_repos_name) echo BTS_D_SC_LFS_2015_08 ;;
            SVN_cli_args) echo "" ;;
            *) echo $1
        esac
    }
    # TODO: demx2fk3 2015-08-05 REMOVE ME, this is required for old implementation
    copyArtifactsToWorkspace() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/
        echo PS_LFS_OS_2015_08_0001 > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
        echo SDK1=tag_SDK1 >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
        echo SDK2=tag_SDK2 >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
        echo SDK3=tag_SDK3 >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
        echo SDK=tag_SDK   >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/
        echo PS_LFS_OS_2015_08_0001 > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
        echo SDK1=tag_SDK1 >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
        echo SDK2=tag_SDK2 >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
        echo SDK3=tag_SDK3 >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
        echo SDK=tag_SDK   >> ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    copyFileFromWorkspaceToBuildDirectory() {
        mockedCommand "copyFileFromWorkspaceToBuildDirectory $@"
    }
    runOnMaster() {
        mockedCommand "runOnMaster $@"
        return 1
    }
    databaseEventSubReleaseStarted() {
        mockedCommand "databaseEventSubReleaseStarted $@"
    }
    sleep() {
        return
    }

    return
}
setUp() {

    export UT_SVN_ROOT=$(createTempDirectory)
    svnadmin create ${UT_SVN_ROOT}

    svn -q mkdir --parents -m "init" file://${UT_SVN_ROOT}/isource/svnroot/BTS_D_SC_LFS_2015_08/os/branches
    svn -q mkdir --parents -m "init" file://${UT_SVN_ROOT}/isource/svnroot/BTS_D_SC_LFS_2015_08/os/tags

    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Wait_for_Release
    export UPSTREAM_BUILD=1234

    # TODO: demx2fk3 2015-08-05 REMOVE ME, this is required for old implementation
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_2015_08_0001

    export JOB_NAME=LFS_Prod_-_trunk_-_Releasing_-_createReleaseTag
    export BUILD_NUMBER=1234

    cat /dev/null > ${UT_MOCKED_COMMANDS}

    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace

    export UT_CI_LFS_SHARE=$(createTempDirectory)
    mkdir -p ${UT_CI_LFS_SHARE}/PS_LFS_OS_2015_08_0001

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # TODO: demx2fk3 2015-08-05 REMOVE ME, this is required for old implementation
    # assertTrue "createReleaseTag LFS_CI_-_trunk_-_Build 1234"
    # assertTrue "usecase_LFS_RELEASE_CREATE_RELEASE_TAG"
    usecase_LFS_RELEASE_CREATE_RELEASE_TAG

    assertTrue   "REL tag exists"                          "svn info file://${UT_SVN_ROOT}/isource/svnroot/BTS_D_SC_LFS_2015_08/tags/PS_LFS_REL_2015_08_0001"
    assertEquals "List tags ok" "PS_LFS_REL_2015_08_0001/" "$(svn ls file://${UT_SVN_ROOT}/isource/svnroot/BTS_D_SC_LFS_2015_08/tags)"
    
    local got=$(createTempFile)
    local expect=$(createTempFile)
    cat <<EOF > ${expect}
/isource/svnroot/BTS_D_SC_LFS_2015_08/os/tags/PS_LFS_OS_2015_08_0001 os 
/isource/svnroot/BTS_D_SC_LFS_2015_08/sdk sdk
EOF
    svn pg svn:externals file://${UT_SVN_ROOT}/isource/svnroot/BTS_D_SC_LFS_2015_08/tags/PS_LFS_REL_2015_08_0001 > ${got}
    assertEquals "$(cat ${expect})" "$(cat ${got})"

    return
}

source lib/shunit2

exit 0
