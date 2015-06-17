#!/bin/bash

source test/common.sh
source lib/fingerprint.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        echo "LABEL" > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "getFingerprintOfCurrentJob"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject LFS_CI_-_trunk_-_Test 1234 fsmci
EOF
    assertExecutedCommands ${expect}
    
    local value=$(getFingerprintOfCurrentJob)
    assertEquals "3fc45e97ece3a6d14e9826afc4746a45" "${value}" 

    return
}

test2() {

    mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
    echo "LABEL2" > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label

    assertTrue "getFingerprintOfCurrentJob"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}
    
    local value=$(getFingerprintOfCurrentJob)
    assertEquals "4a90b1ffd7c703d7fd0775d246f5cc62" "${value}" 

    return
}

source lib/shunit2

exit 0
