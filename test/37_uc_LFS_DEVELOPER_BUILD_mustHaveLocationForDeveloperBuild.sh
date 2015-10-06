#!/bin/bash

source test/common.sh

source lib/uc_developer_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        echo LABEL          > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
        echo ${UT_LOCATION} > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/location
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export UPSTREAM_PROJECT=LFS_DEV_-_developer_-_Build
    export UPSTREAM_BUILD=1234
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fcmd
    export UT_LOCATION=LOCATION
    assertTrue "mustHaveLocationForSpecialBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci
EOF
    assertExecutedCommands ${expect}

    mustHaveLocationForSpecialBuild
    assertEquals "LOCATION" "${LFS_CI_GLOBAL_LOCATION_NAME}"

    return
}

test2() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fcmd
    export UT_LOCATION=location_name
    assertTrue "mustHaveLocationForSpecialBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci
EOF
    assertExecutedCommands ${expect}

    mustHaveLocationForSpecialBuild
    assertEquals "location_name" "${LFS_CI_GLOBAL_LOCATION_NAME}"

    return
}
test3() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fcmd
    export UT_LOCATION=pronb-developer
    assertTrue "mustHaveLocationForSpecialBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci
EOF
    assertExecutedCommands ${expect}

    mustHaveLocationForSpecialBuild
    assertEquals "pronb-developer" "${LFS_CI_GLOBAL_LOCATION_NAME}"

    return
}

test4() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fcmd
    export UT_LOCATION=LOCATION
    assertTrue "mustHaveLocationForSpecialBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci
EOF
    assertExecutedCommands ${expect}

    mustHaveLocationForSpecialBuild
    assertEquals "LOCATION" "${LFS_CI_GLOBAL_LOCATION_NAME}"

    return
}

test5() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fcmd
    export UT_LOCATION=location_name
    assertTrue "mustHaveLocationForSpecialBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci
EOF
    assertExecutedCommands ${expect}

    mustHaveLocationForSpecialBuild
    assertEquals "location_name" "${LFS_CI_GLOBAL_LOCATION_NAME}"

    return
}
test6() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fcmd
    export UT_LOCATION=pronb-developer
    assertTrue "mustHaveLocationForSpecialBuild"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject ${UPSTREAM_PROJECT} ${UPSTREAM_BUILD} fsmci
EOF
    assertExecutedCommands ${expect}

    mustHaveLocationForSpecialBuild
    assertEquals "pronb-developer" "${LFS_CI_GLOBAL_LOCATION_NAME}"

    return
}
source lib/shunit2

exit 0
