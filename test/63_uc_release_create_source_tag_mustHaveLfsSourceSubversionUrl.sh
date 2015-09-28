#!/bin/bash 
source test/common.sh
source lib/uc_release_create_source_tag.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        echo $1
    }
    normalizeSvnUrl() {
        echo $1_normalized
    }

    return
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_2015_09_0001
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    # assertTrue "_mustHaveLfsSourceSubversionUrl"
    _mustHaveLfsSourceSubversionUrl

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
EOF
    assertExecutedCommands ${expect}

    assertEquals "svn url"      "${svnUrl}"      "lfsSourceRepos_normalized"
    assertEquals "svn url os"   "${svnUrlOs}"    "lfsSourceRepos_normalized/os"
    assertEquals "release name" "${osLabelName}" "PS_LFS_OS_2015_09_0001"

    return
}

source lib/shunit2

exit 0
