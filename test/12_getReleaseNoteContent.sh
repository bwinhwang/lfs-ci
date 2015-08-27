#!/bin/bash

source lib/common.sh

initTempDirectory

export WORKSPACE=$(createTempDirectory)

oneTimeSetUp() {
    mkdir -p ${WORKSPACE}
    cp -f ${LFS_CI_ROOT}/test/data/12_getReleaseNoteContent.xml ${WORKSPACE}/changelog.xml
}
oneTimeTearDown() {
    rm -rf ${WORKSPACE}
}

testGetReleaseNoteContent() {

    cd ${WORKSPACE}

    local rn_txt=$(createTempFile)

    assertTrue "${LFS_CI_ROOT}/bin/getReleaseNoteContent -t TAG"
    ${LFS_CI_ROOT}/bin/getReleaseNoteContent -t TAG > ${rn_txt}
    assertEquals "value from getConfig" \
        "$(cat ${LFS_CI_ROOT}/test/data/12_getReleaseNoteContent.txt)" \
        "$(cat ${rn_txt})"
}

source lib/shunit2

exit 0

