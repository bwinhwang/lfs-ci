#!/bin/bash

source test/common.sh
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
        mkdir -p ${WORKSPACE}/workspace/bld/bld-knife-input/
        echo "foo=bar" > ${WORKSPACE}/workspace/bld/bld-knife-input/knife-requestor.txt
    }
    getUsedSdkVersions() {
        mockedCommand "getUsedSdkVersions $@"
        echo SDK1 SDK2
    }
    mustHaveNextCiLabelName() {
        mockedCommand "mustHaveNextCiLabelName $@"
    }
    getNextCiLabelName() {
        echo KNIFE_LABEL
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
    export KNIFE_LFS_BASELINE=PS_LFS_OS_2015_01_0001
    export UPSTREAM_PROJECT=upstream_project
    export UPSTREAM_BUILD=123
    export JOB_NAME=LFS_KNIFE_-_knife_-_Build
    export BUILD_NUMBER=1234
    export LFS_CI_GLOBAL_BRANCH_NAME=trunk

    assertTrue "usecase_LFS_KNIFE_PACKAGE"

    local expect=$(createTempFile)

# getUsedSdkVersions 
# execute tar -rv --transform=s:^\./:sdk3/: -C /build/home/CI_LFS/SDKs/SDK1/ -f ${WORKSPACE}/workspace/lfs-knife.tar .
# execute tar -rv --transform=s:^\./:sdk3/: -C /build/home/CI_LFS/SDKs/SDK2/ -f ${WORKSPACE}/workspace/lfs-knife.tar .
# execute mkdir -p ${WORKSPACE}/workspace/bld/

cat <<EOF > ${expect}
ci_job_package 
mustHaveNextCiLabelName 
execute tar -cv --transform=s:^\./:os/: -C ${WORKSPACE}/workspace/upload/ -f ${WORKSPACE}/workspace/KNIFE_LABEL.tar .
execute ${LFS_CI_ROOT}/bin/pigz ${WORKSPACE}/workspace/KNIFE_LABEL.tar
uploadKnifeToStorage ${WORKSPACE}/workspace/KNIFE_LABEL.tar.gz
copyFileToArtifactDirectory ${WORKSPACE}/workspace/.00_README.txt
execute ${LFS_CI_ROOT}/bin/sendReleaseNote -r ${WORKSPACE}/workspace/.00_README.txt -t KNIFE_LABEL -n -f ${LFS_CI_ROOT}/etc/file.cfg
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

