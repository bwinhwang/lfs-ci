#!/bin/bash

source test/common.sh
source lib/uc_vtc_plus_lfs.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getJobJobNameFromFingerprint() {
        mockedCommand "getJobJobNameFromFingerprint $@"
        echo build_job
    }
    getJobBuildNumberFromFingerprint() {
        mockedCommand "getJobBuildNumberFromFingerprint $@"
        echo 1234
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
        mkdir -p ${WORKSPACE}/workspace/bld-externalComponents-summary
        echo "SDK = SDK_1_2"  >> ${WORKSPACE}/workspace/bld-externalComponents-summary/externalComponents
        echo "PKG = PKG_1234" >> ${WORKSPACE}/workspace/bld-externalComponents-summary/externalComponents
    }
    setBuildDescription() {
        mockedCommand "setBuildDescription $@"
    }
    getNextCiLabelName() {
        mockedCommand "getNextCiLabelName $@"
        echo LABEL
    }
    return
}

setUp() {
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_foobar
    export BUILD_NUMBER=1234
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # assertTrue "_setBuildDescriptionForVtc"
    _setBuildDescriptionForVtc

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getJobJobNameFromFingerprint Build_-_FSM-r4_-_fsm4_axm:
getJobBuildNumberFromFingerprint Build_-_FSM-r4_-_fsm4_axm:
copyAndExtractBuildArtifactsFromProject build_job 1234
getNextCiLabelName 
setBuildDescription LFS_CI_-_trunk_-_foobar 1234 LABEL<br>
 PKG_1234<br>
 SDK_1_2<br>
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

