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

    mkdir -p ${WORKSPACE}/workspace/bld/bld-externalComponents-summary
    mkdir -p ${WORKSPACE}/workspace/rel/bld/bld-externalComponents-summary

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_createLfsRelReleaseNoteXml"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/rel/bld/bld-externalComponents-summary
execute cd ${WORKSPACE}/workspace/rel/
execute grep sdk ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents
execute -n ${LFS_CI_ROOT}/bin/getReleaseNoteXML -t PS_LFS_REL_BUILD_NAME -o PS_LFS_REL_OLD_BUILD_NAME -T OS -P LFS -f ${LFS_CI_ROOT}/etc/lfs-ci.cfg
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
