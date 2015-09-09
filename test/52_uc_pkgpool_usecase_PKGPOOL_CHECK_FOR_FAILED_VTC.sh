#!/bin/bash

source test/common.sh

source lib/uc_pkgpool.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    execute() {
        mockedCommand "execute $@"
        if [[ ${UT_COUNTER} == 1 ]] ; then
            echo output line from tar tvf vtc.tar.gz
        fi
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release
        echo buildName > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/label
    }
    mustExistFile() {
        mockedCommand "mustExistFile $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=PKGPOOL_CI_-_trunk_-_Build_vtc_check
    export BUILD_NUMBER=123
    export UPSTREAM_PROJECT=PKGPOOL_CI_-_trunk_-_Build
    export UPSTREAM_BUILD=123
    mkdir ${WORKSPACE}/src/
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

test1() {
    export UT_COUNTER=0

    assertFalse "failed" "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
copyAndExtractBuildArtifactsFromProject PKGPOOL_CI_-_trunk_-_Build 123 pkgpool
getConfig PKGPOOL_location_on_share
mustExistFile PKGPOOL_location_on_share/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
execute -n tar tvf PKGPOOL_location_on_share/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
EOF
    assertExecutedCommands ${expect}

    return
}


test2() {
    export UT_COUNTER=1

    assertTrue "ok" "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
copyAndExtractBuildArtifactsFromProject PKGPOOL_CI_-_trunk_-_Build 123 pkgpool
getConfig PKGPOOL_location_on_share
mustExistFile PKGPOOL_location_on_share/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
execute -n tar tvf PKGPOOL_location_on_share/buildName/arm-cortexa15-linux-gnueabihf-vtc.tar.gz
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
