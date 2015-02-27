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
    

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fcmd
    export UT_LOCATION=LOCATION
    # assertTrue "mustHaveLocationForDeveloperBuild"
    mustHaveLocationForDeveloperBuild

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject fsmci
EOF
    assertExecutedCommands ${expect}
    assertEquals "LOCATION" "${LFS_CI_GLOBAL_BRANCH_NAME}"

    return
}

test2() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fcmd
    export UT_LOCATION=trunk
    # assertTrue "mustHaveLocationForDeveloperBuild"
    mustHaveLocationForDeveloperBuild

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject fsmci
EOF
    assertExecutedCommands ${expect}
    assertEquals "trunk" "${LFS_CI_GLOBAL_BRANCH_NAME}"

    return
}
test3() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r2_-_fcmd
    export UT_LOCATION=pronb-developer
    # assertTrue "mustHaveLocationForDeveloperBuild"
    mustHaveLocationForDeveloperBuild

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject fsmci
EOF
    assertExecutedCommands ${expect}
    assertEquals "pronb-developer" "${LFS_CI_GLOBAL_BRANCH_NAME}"

    return
}

test4() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fcmd
    export UT_LOCATION=LOCATION
    # assertTrue "mustHaveLocationForDeveloperBuild"
    mustHaveLocationForDeveloperBuild

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject fsmci
EOF
    assertExecutedCommands ${expect}
    assertEquals "LOCATION_FSMR4" "${LFS_CI_GLOBAL_BRANCH_NAME}"

    return
}

test5() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fcmd
    export UT_LOCATION=trunk
    # assertTrue "mustHaveLocationForDeveloperBuild"
    mustHaveLocationForDeveloperBuild

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject fsmci
EOF
    assertExecutedCommands ${expect}
    assertEquals "FSM_R4_DEV" "${LFS_CI_GLOBAL_BRANCH_NAME}"

    return
}
test6() {
    export JOB_NAME=LFS_DEV_-_developer_-_Build_-_FSM-r4_-_fcmd
    export UT_LOCATION=pronb-developer
    # assertTrue "mustHaveLocationForDeveloperBuild"
    mustHaveLocationForDeveloperBuild

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyAndExtractBuildArtifactsFromProject fsmci
EOF
    assertExecutedCommands ${expect}
    assertEquals "FSM_R4_DEV" "${LFS_CI_GLOBAL_BRANCH_NAME}"

    return
}
source lib/shunit2

exit 0
