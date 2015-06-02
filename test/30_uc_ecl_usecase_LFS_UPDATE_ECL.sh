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
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
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
}
oneTimeTearDown() {
    true
}
setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    touch  ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Build
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
execute mkdir -p ${WORKSPACE}/workspace
getConfig LFS_CI_UC_update_ecl_required_artifacts
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Build 1234 fsmci
setBuildDescription LABEL_NAME
getConfig LFS_CI_uc_update_ecl_url
updateAndCommitEcl http://svn/ecl/url1
updateAndCommitEcl http://svn/ecl/url2
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

