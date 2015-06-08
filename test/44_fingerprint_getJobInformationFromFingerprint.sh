#!/bin/bash

source test/common.sh
source lib/fingerprint.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    copyArtifactsToWorkspace() {
        mockedCommand "copyArtifactsToWorkspace $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary/
        echo "LABEL" > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
    }
    runOnMaster() {
        mockedCommand "runOnMaster $@"
        if [[ ${UT_RUN_ON_MASTER_FAIL} ]] ; then
            exit 1
        fi
        cat ${LFS_CI_ROOT}/test/data/44_fingerprint.xml
    }
    execute() {
        mockedCommand "execute $@"
        shift
        $@
    }
    createTempFile() {
        local cnt=$(cat ${UT_TMPDIR}/.cnt)
        cnt=$((cnt + 1 ))
        echo ${cnt} > ${UT_TMPDIR}/.cnt
        touch ${UT_TMPDIR}/tmp.${cnt}
        echo ${UT_TMPDIR}/tmp.${cnt}
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export UPSTREAM_PROJECT=LFS_CI_-_trunk_-_Test
    export UPSTREAM_BUILD=1234
    export JOB_NAME=LFS_CI_-_trunk_-_wait_for_release
    export WORKSPACE=$(createTempDirectory)
    export UT_TMPDIR=$(createTempDirectory)
    export JENKINS_HOME=/var/fpwork/psulm/lfs-jenkins/home
    echo 0 > ${UT_TMPDIR}/.cnt
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${UT_TMPDIR}
    return
}

test1() {
    assertTrue "_getJobInformationFromFingerprint _Build: 1"
    local jenkinsRoot=$(getConfig jenkinsRoot)

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Test 1234 fsmci
runOnMaster [[ -e ${jenkinsRoot}/home/fingerprints/3f/c4/5e97ece3a6d14e9826afc4746a45.xml ]] && cat ${jenkinsRoot}/home/fingerprints/3f/c4/5e97ece3a6d14e9826afc4746a45.xml
execute -n ${LFS_CI_ROOT}/bin/getFingerprintData ${UT_TMPDIR}/tmp.1
EOF
    assertExecutedCommands ${expect}
    local value=$(_getJobInformationFromFingerprint _Build: 1)
    assertEquals "LFS_CI_-_trunk_-_Build" "${value}"
    
    return
}

test2() {
    assertTrue "_getJobInformationFromFingerprint _Build: 2"
    local jenkinsRoot=$(getConfig jenkinsRoot)

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Test 1234 fsmci
runOnMaster [[ -e ${jenkinsRoot}/home/fingerprints/3f/c4/5e97ece3a6d14e9826afc4746a45.xml ]] && cat ${jenkinsRoot}/home/fingerprints/3f/c4/5e97ece3a6d14e9826afc4746a45.xml
execute -n ${LFS_CI_ROOT}/bin/getFingerprintData ${UT_TMPDIR}/tmp.1
EOF
    assertExecutedCommands ${expect}
    local value=$(_getJobInformationFromFingerprint _Build: 2)
    assertEquals "7901" "${value}"
    
    return
}

test3() {
    export UT_RUN_ON_MASTER_FAIL=1
    assertFalse "_getJobInformationFromFingerprint _Build: 2"
    local jenkinsRoot=$(getConfig jenkinsRoot)

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyArtifactsToWorkspace LFS_CI_-_trunk_-_Test 1234 fsmci
runOnMaster [[ -e ${jenkinsRoot}/home/fingerprints/3f/c4/5e97ece3a6d14e9826afc4746a45.xml ]] && cat ${jenkinsRoot}/home/fingerprints/3f/c4/5e97ece3a6d14e9826afc4746a45.xml
EOF
    assertExecutedCommands ${expect}
    return
}
source lib/shunit2

exit 0
