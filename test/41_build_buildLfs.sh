#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    createTempFile() {
        echo /tmp/${USER}-tmpFile
    }
    mustHaveNextCiLabelName() {
        return
    }
    getNextCiLabelName() {
        echo PS_LFS_CI_LABEL
    }
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    storeExternalComponentBaselines() {
        mockedCommand "storeExternalComponentBaselines $@"
    }
    storeRevisions() {
        mockedCommand "storeRevisions $@"
    }
    createRebuildScript() {
        mockedCommand "createRebuildScript $@"
    }
    execute() {
        mockedCommand "execute $@"
    }
    build() {
        mockedCommand "build $@"
        echo "targetName"
    }

}
oneTimeTearDown() {
    true
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
}
tearDown() {
    rm -rf /tmp/${USER}-tmpFile
}

testBuildLfs() {
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_CI_-_trunk_-_Build_-_FSM-r2_-_fcmd
    assertTrue "buildLfs"

    local expect=$(createTempFile)
cat <<EOF > ${expect}
execute cd ${WORKSPACE}/workspace
storeExternalComponentBaselines 
storeRevisions fcmd
createRebuildScript fcmd
execute -n ${LFS_CI_ROOT}/bin/sortBuildsFromDependencies fcmd makefile PS_LFS_CI_LABEL
build -C src-project final-build-target_LFS_FSM-r2
execute make -f /tmp/${USER}-tmpFile targetName JOBS=32
EOF

    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/shunit2

exit 0

