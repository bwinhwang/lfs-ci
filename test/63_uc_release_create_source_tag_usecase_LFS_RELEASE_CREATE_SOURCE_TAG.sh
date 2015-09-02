#!/bin/bash

source test/common.sh
source lib/uc_release_create_source_tag.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in 
            *) echo $1 ;;
        esac
    }
    mustBePreparedForReleaseTask() {
        mockedCommand "mustBePreparedForReleaseTask $@"
        export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_2015_09_0001
    }
    _mustHaveLfsSourceSubversionUrl() {
        mockedCommand "_mustHaveLfsSourceSubversionUrl $@"
        export svnUrl=http://svn1/
        export svnUrlOs=http://svn1/os
    }
    _createUsedRevisionsFile() {
        mockedCommand "_createUsedRevisionsFile $@"
        mkdir -p ${WORKSPACE}/workspace/rev/
        echo src-bos http://svn/src-bos 1234 > ${WORKSPACE}/workspace/rev/fsmr2
    }
    _prepareSubversion() {
        mockedCommand "_prepareSubversion $@"
    }
    mustExistBranchInSubversion() {
        mockedCommand "mustExistBranchInSubversion $@"
    }
    _copySourceDirectoryToBranch() {
        mockedCommand "_copySourceDirectoryToBranch $@"
    }
    _createSourceTag() {
        mockedCommand "_createSourceTag $@"
    }
    return
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_RELEASE_CREATE_SOURCE_TAG"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustBePreparedForReleaseTask 
_mustHaveLfsSourceSubversionUrl 
_createUsedRevisionsFile 
_prepareSubversion 
getConfig LFS_PROD_uc_release_source_tag_prefix -t target:fsmr2
mustExistBranchInSubversion http://svn1/os/branches/ fsmr2
_copySourceDirectoryToBranch fsmr2 src-bos http://svn/src-bos 1234
_createSourceTag 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
