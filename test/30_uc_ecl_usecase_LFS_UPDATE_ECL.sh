#!/bin/bash

source test/common.sh
source lib/uc_ecl.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        if [[ $1 == mkdir ]] ; then
            $@
        fi
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
    updateAndCommitEcl() {
        mockedCommand "updateAndCommitEcl $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            LFS_CI_UC_update_ecl_required_artifacts)
                echo fsmci
            ;;
            LFS_CI_uc_update_ecl_url)
                echo http://svn/ecl/url1 http://svn/ecl/url2
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

    local expect=$(createTempFile)
cat <<EOF > ${expect}
mustHavePreparedWorkspace 
getConfig LFS_CI_uc_update_ecl_url
getBuildJobNameFromFingerprint 
getBuildBuildNumberFromFingerprint 
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Build 1234 externalComponents
updateAndCommitEcl http://svn/ecl/url1
updateAndCommitEcl http://svn/ecl/url2
createArtifactArchive 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

