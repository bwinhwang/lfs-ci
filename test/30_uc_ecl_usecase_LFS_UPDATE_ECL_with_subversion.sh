#!/bin/bash

source test/common.sh
source lib/uc_ecl.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustHaveNextCiLabelName() {
        mockedCommand "mustHaveNextCiLabelName $@"
    }
    getNextCiLabelName() {
        mockedCommand "getNextCiLabelName $@"
        echo PS_LFS_OS_label
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    createReleaseLinkOnCiLfsShare() {
        mockedCommand "createReleaseLinkOnCiLfsShare $@"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        echo LABEL_NAME > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
        return
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_UC_update_ecl_required_artifacts)
                echo fsmci
            ;;
            LFS_CI_uc_update_ecl_url)
                echo file://${SVN_ROOT}/trunk/ECL_BASE/
            ;;
            LFS_CI_uc_update_ecl_key_names)
                echo ECL_PS_LFS_REL ECL_PS_LFS_OS ECL_PS_LFS_INTERFACE_REV
            ;;
            LFS_CI_uc_update_ecl_can_commit_ecl)
                echo 1
            ;;
        esac
    }
    getBuildJobNameFromFingerprint() {
        mockedCommand "getBuildJobNameFromFingerprint $@"
        echo LFS_CI_-_trunk_-_Build
    }
    getBuildBuildNumberFromFingerprint() {
        mockedCommand "getBuildBuildNumberFromFingerprint $@"
        echo 1234
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
    }
    createArtifactArchive() {
        mockedCommand "createArtifactArchive $@"
    }
                                   
}
oneTimeTearDown() {
    true
}
setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    touch  ${UT_MOCKED_COMMANDS}

    export SVN_ROOT=$(createTempDirectory)
    svnadmin create ${SVN_ROOT}
    svn mkdir -q -m init file://${SVN_ROOT}/trunk/
    svn mkdir -q -m init file://${SVN_ROOT}/trunk/ECL_BASE
    export WS=$(createTempDirectory)
    svn co -q file://${SVN_ROOT}/trunk/ECL_BASE ${WS}
    cat <<EOF > ${WS}/ECL
ECL_SWBUILD=SW_BUILD_0_70_2_BL
ECL_HDBDE=HDBDE_1.200

ECL_PS_LFS_OS=MD1_PS_LFS_OS_2015_05_0043
ECL_PS_LFS_REL=MD1_PS_LFS_REL_2015_05_0043
ECL_PS_LFS_INTERFACE_REV=453
ECL_PS_LRC_LCP_LFS_OS=FB_LRC_LCP_PS_LFS_OS_2015_04_0090
ECL_PS_LRC_LCP_LFS_REL=FB_LRC_LCP_PS_LFS_REL_2015_04_0090
ECL_PS_FZM_LFS_OS=MD1_FZM_PS_LFS_OS_2015_05_06
ECL_PS_FZM_LFS_REL=MD1_FZM_PS_LFS_REL_2015_05_06

ECL_GLOBAL_ENV=GLOBAL_ENV_11_19
ECL_PS_ENV=/isource/svnroot/BTS_I_PS/MD11505/trunk@21277

EOF
    svn add -q ${WS}/ECL
    svn ci -q -m "add ECL" ${WS}

    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Build
    export JOB_NAME=LFS_CI_-_trunk_-_wait_for_release
    export BUILD_NUMBER=123
    export UPSTREAM_BUILD=1234
    return
}
tearDown() {
    true 
}

test1() {
    assertTrue "usecase_LFS_UPDATE_ECL"
    # usecase_LFS_UPDATE_ECL

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustHavePreparedWorkspace 
getConfig LFS_CI_uc_update_ecl_url
getBuildJobNameFromFingerprint 
getBuildBuildNumberFromFingerprint 
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 externalComponents
getConfig SVN_cli_args -t command:checkout
getConfig LFS_CI_uc_update_ecl_key_names
mustHaveNextCiLabelName 
getNextCiLabelName 
mustHaveNextCiLabelName 
getNextCiLabelName 
getConfig SVN_cli_args -t command:diff
getConfig LFS_CI_uc_update_ecl_can_commit_ecl
getConfig SVN_cli_args -t command:commit
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
ECL_SWBUILD=SW_BUILD_0_70_2_BL
ECL_HDBDE=HDBDE_1.200

ECL_PS_LFS_OS=PS_LFS_OS_label
ECL_PS_LFS_REL=PS_LFS_REL_label
ECL_PS_LFS_INTERFACE_REV=454
ECL_PS_LRC_LCP_LFS_OS=FB_LRC_LCP_PS_LFS_OS_2015_04_0090
ECL_PS_LRC_LCP_LFS_REL=FB_LRC_LCP_PS_LFS_REL_2015_04_0090
ECL_PS_FZM_LFS_OS=MD1_FZM_PS_LFS_OS_2015_05_06
ECL_PS_FZM_LFS_REL=MD1_FZM_PS_LFS_REL_2015_05_06

ECL_GLOBAL_ENV=GLOBAL_ENV_11_19
ECL_PS_ENV=/isource/svnroot/BTS_I_PS/MD11505/trunk@21277

EOF

    local eclWorkspace=$(createTempDirectory)
    svn co -q file://${SVN_ROOT}/trunk/ECL_BASE/ ${eclWorkspace}
    diff -rub ${expect} ${eclWorkspace}/ECL 
    assertEquals "$(cat ${expect})" "$(cat ${eclWorkspace}/ECL)" 
    return
}

source lib/shunit2

exit 0

