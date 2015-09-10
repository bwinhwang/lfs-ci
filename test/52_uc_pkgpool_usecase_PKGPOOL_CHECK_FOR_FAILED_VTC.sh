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
        return ${UT_GREP_FAILED}
    }
    mustHavePreparedWorkspace() {
        mockedCommand "mustHavePreparedWorkspace $@"
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release
        echo buildName > ${WORKSPACE}/workspace/bld/bld-pkgpool-release/label
        mkdir -p ${WORKSPACE}/workspace/bld/bld-pkgpool-release/logs
        case ${_shunit_test_} in
            test1)
                # touch ${WORKSPACE}/workspace/bld/bld-pkgpool-release/logs/arm-cortexa15-linux-gnueabihf-vtc.log.gz
            ;;
            test2)
                touch ${WORKSPACE}/workspace/bld/bld-pkgpool-release/logs/arm-cortexa15-linux-gnueabihf-vtc.log.gz
            ;;
            test3)
                touch ${WORKSPACE}/workspace/bld/bld-pkgpool-release/logs/arm-cortexa15-linux-gnueabihf-vtc.log.gz
            ;;
        esac            
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
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${CI_LOGGING_LOGFILENAME}
    return
}

test1() {
    export UT_GREP_FAILED=0
    assertTrue "ok" "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
copyAndExtractBuildArtifactsFromProject PKGPOOL_CI_-_trunk_-_Build 123 pkgpool
EOF
    assertExecutedCommands ${expect}

    return
}


test2() {
    export UT_GREP_FAILED=1
    assertTrue "ok" "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
copyAndExtractBuildArtifactsFromProject PKGPOOL_CI_-_trunk_-_Build 123 pkgpool
execute -i zgrep -s LVTC FSMR4 BUILD FAILED ${WORKSPACE}/workspace/bld/bld-pkgpool-release/logs/arm-cortexa15-linux-gnueabihf-vtc.log.gz
EOF
    assertExecutedCommands ${expect}

    return
}

test3() {
    export UT_GREP_FAILED=0
    assertFalse "failed" "usecase_PKGPOOL_CHECK_FOR_FAILED_VTC"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHavePreparedWorkspace --no-build-description
copyAndExtractBuildArtifactsFromProject PKGPOOL_CI_-_trunk_-_Build 123 pkgpool
execute -i zgrep -s LVTC FSMR4 BUILD FAILED ${WORKSPACE}/workspace/bld/bld-pkgpool-release/logs/arm-cortexa15-linux-gnueabihf-vtc.log.gz
execute -i -n zcat ${WORKSPACE}/workspace/bld/bld-pkgpool-release/logs/arm-cortexa15-linux-gnueabihf-vtc.log.gz
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
