#!/bin/bash

source test/common.sh

source lib/uc_developer_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    ci_job_package() {
        mockedCommand "ci_job_package $@"
        mkdir -p ${WORKSPACE}/workspace/bld/bld-fsmci-summary
        echo LABEL > ${WORKSPACE}/workspace/bld/bld-fsmci-summary/label
    }
    specialBuildUploadAndNotifyUser() {
        mockedCommand "specialBuildUploadAndNotifyUser $@"
    }
    linkFileToArtifactsDirectory() {
        mockedCommand "linkFileToArtifactsDirectory $@"
    }
    mustHaveLocationForSpecialBuild() {
        mockedCommand "mustHaveLocationForSpecialBuild $@"
    }

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    export JOB_NAME=LFS_DEV_-_developer_-_Package_-_package
    export BUILD_NUMBER=1234
    export UPSTREAM_PROJECT=LFS_DEV_-_developer_-_Build
    export UPSTREAM_BUILD=5432
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "usecase_LFS_DEVELOPER_PACKAGE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveLocationForSpecialBuild 
ci_job_package 
specialBuildUploadAndNotifyUser DEV
linkFileToArtifactsDirectory /build/home/${USER}/privateBuilds/LABEL.tar.gz
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
