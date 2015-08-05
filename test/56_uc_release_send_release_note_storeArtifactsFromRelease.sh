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
    copyFileToArtifactDirectory() {
        mockedCommand "copyFileToArtifactDirectory $@"
    }
    linkFileToArtifactsDirectory() {
        mockedCommand "linkFileToArtifactsDirectory $@"
    }
    getBuildDirectoryOnMaster() {
        mockedCommand "getBuildDirectoryOnMaster $@"
        echo /path/to/jenkins/jobs/${JOB_NAME}/builds/${BUILD_NUMBER}/
    }
    executeOnMaster() {
        mockedCommand "executeOnMaster $@"
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    
    mkdir -p ${WORKSPACE}/workspace/bld/bld-lfs-release/
    touch ${WORKSPACE}/workspace/bld/bld-lfs-release/changelog.xml
    touch ${WORKSPACE}/workspace/bld/bld-lfs-release/release_note.xml
    touch ${WORKSPACE}/workspace/bld/bld-lfs-release/release_note.txt

    export JOB_NAME=LFS_PROD_-_trunk_-_Releasing_-_summary
    export BUILD_NUMBER=1234

    export LFS_PROD_RELEASE_CURRENT_TAG_NAME=PS_LFS_OS_BUILD_NAME

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_storeArtifactsFromRelease"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyFileToArtifactDirectory ${WORKSPACE}/workspace/bld/bld-lfs-release/changelog.xml
copyFileToArtifactDirectory ${WORKSPACE}/workspace/bld/bld-lfs-release/release_note.txt
copyFileToArtifactDirectory ${WORKSPACE}/workspace/bld/bld-lfs-release/release_note.xml
getConfig artifactesShare
linkFileToArtifactsDirectory artifactesShare/LFS_PROD_-_trunk_-_Releasing_-_summary/1234
getConfig LFS_CI_UC_package_copy_to_share_real_location
getBuildDirectoryOnMaster 
executeOnMaster ln -sf LFS_CI_UC_package_copy_to_share_real_location/PS_LFS_OS_BUILD_NAME /path/to/jenkins/jobs/LFS_PROD_-_trunk_-_Releasing_-_summary/builds/1234//archive/release
EOF
    assertExecutedCommands ${expect}

    return
}


source lib/shunit2

exit 0
