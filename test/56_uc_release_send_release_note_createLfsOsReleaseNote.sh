#!/bin/bash

source test/common.sh
source lib/uc_release_send_release_note.sh

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
    execute() {
        mockedCommand "execute $@"
    }
    copyFileFromBuildDirectoryToWorkspace() {
        mockedCommand "copyFileFromBuildDirectoryToWorkspace $@"
    }
    mustBeValidXmlReleaseNote() {
        mockedCommand "mustBeValidXmlReleaseNote $@"
    }
    mustExistFile() {
        mockedCommand "mustExistFile $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)

    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME=PS_LFS_OS_OLD_BUILD_NAME
    export LFS_PROD_RELEASE_PREVIOUS_TAG_NAME_REL=PS_LFS_REL_OLD_BUILD_NAME
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME
    export LFS_PROD_RELEASE_CURRENT_TAG_NAME_REL=PS_LFS_REL_BUILD_NAME

    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-ci.cfg

    export JOB_NAME=LFS_CI_-_trunk_-_Build
    export BUILD_NUMBER=1234

    mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd
    touch    ${WORKSPACE}/workspace/bld/bld-externalComponents-fcmd/usedRevisions.txt

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_createLfsOsReleaseNote"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/os
copyFileFromBuildDirectoryToWorkspace LFS_CI_-_trunk_-_Build 1234 changelog.xml
execute mv ${WORKSPACE}/changelog.xml ${WORKSPACE}/workspace/os/changelog.xml
mustExistFile ${WORKSPACE}/workspace/os/changelog.xml
execute cd ${WORKSPACE}/workspace/os/
execute ln -sf ../bld .
execute rm -f releasenote.txt releasenote.xml
execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteContent -t PS_LFS_OS_BUILD_NAME
execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t PS_LFS_OS_BUILD_NAME -o PS_LFS_OS_OLD_BUILD_NAME -f ${LFS_CI_ROOT}/etc/lfs-ci.cfg -T OS -P LFS
execute mv -f ${WORKSPACE}/workspace/os/releasenote.xml ${WORKSPACE}/workspace/os/os_releasenote.xml
mustBeValidXmlReleaseNote ${WORKSPACE}/workspace/os/os_releasenote.xml
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
