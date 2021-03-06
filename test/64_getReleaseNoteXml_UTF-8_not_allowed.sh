#!/bin/bash

source test/common.sh
source lib/database.sh

setUp() {
    export WORKSPACE=$(createTempDirectory)
    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-ci.cfg
    export type=OS
    export productName=LFS
    cp ${LFS_CI_ROOT}/test/data/64_input_changelog.xml ${WORKSPACE}/changelog.xml

    mkdir -p ${WORKSPACE}/workspace/
    echo -e "File important 1\nLine 2\nA third line 3" > ${WORKSPACE}/workspace/importantNote.txt

    return
}

test1() {
    local releaseNoteXML=$(createTempFile)

    cd ${WORKSPACE}
    ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t TAG_NAME -o OLD_TAG_NAME -f ${LFS_CI_CONFIG_FILE} -P LFS -T OS -L FB1510 > ${releaseNoteXML}

    # cleanup date and time
    sed -i "s^<releaseDate>.*</releaseDate>^<releaseDate>yyyy-mm-dd</releaseDate>^g" ${releaseNoteXML}
    sed -i "s^<releaseTime>.*</releaseTime>^<releaseTime>hh:mm:ssZ</releaseTime>^g" ${releaseNoteXML}

    assertEquals "changelog is not ok" "$(cat ${releaseNoteXML})" "$(cat ${LFS_CI_ROOT}/test/data/64_output_changelog.xml)"
    diff -rub ${releaseNoteXML} ${LFS_CI_ROOT}/test/data/64_output_changelog.xml

    return
}

test2() {
    local releaseNoteTXT=$(createTempFile)

    cd ${WORKSPACE}
    ${LFS_CI_ROOT}/bin/getReleaseNoteContent -t TAG_NAME > ${releaseNoteTXT}

    assertEquals "changelog is not ok" "$(cat ${LFS_CI_ROOT}/test/data/64_output_changelog.txt)" "$(cat ${releaseNoteTXT})" 
    diff -rub ${releaseNoteTXT} ${LFS_CI_ROOT}/test/data/64_output_changelog.txt

    return
}

source lib/shunit2

exit 0
