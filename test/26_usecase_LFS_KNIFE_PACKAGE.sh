#!/bin/bash

source lib/common.sh

initTempDirectory

source lib/uc_knife_build.sh

export UT_MOCKED_COMMANDS=$(createTempFile)

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    ci_job_package() {
        mockedCommand "ci_job_package $@"
    }
    getUsedSdkVersions() {
        mockedCommand "getUsedSdkVersions $@"
        echo SDK1 SDK2
    }
    uploadKnifeToStorage() {
        mockedCommand "uploadKnifeToStorage $@"
    }
    copyFileToArtifactDirectory() {
        mockedCommand "copyFileToArtifactDirectory $@"
    }

}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
}
tearDown() {
    true 
}

test1() {
    export WORKSPACE=$(createTempDirectory)
    export KNIFE_LFS_BASELINE=PS_LFS_OS_2014_01_0001
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build

    assertTrue "usecase_LFS_KNIFE_PACKAGE"

    local expect=$(createTempFile)

# getUsedSdkVersions 
# execute tar -rv --transform=s:^\./:sdk3/: -C /build/home/CI_LFS/SDKs/SDK1/ -f ${WORKSPACE}/workspace/lfs-knife.tar .
# execute tar -rv --transform=s:^\./:sdk3/: -C /build/home/CI_LFS/SDKs/SDK2/ -f ${WORKSPACE}/workspace/lfs-knife.tar .
# execute mkdir -p ${WORKSPACE}/workspace/bld/

cat <<EOF > ${expect}
ci_job_package 
execute tar -cv --transform=s:^\./:os/: -C ${WORKSPACE}/workspace/upload/ -f ${WORKSPACE}/workspace/lfs-knife.tar .
execute gzip ${WORKSPACE}/workspace/lfs-knife.tar
uploadKnifeToStorage 
copyFileToArtifactDirectory .00_README_knife_result.txt
EOF
    assertEquals "$(cat ${expect})" "$(cat ${UT_MOCKED_COMMANDS})"

    return
}

source lib/shunit2

exit 0

