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
        echo "foo=bar" > ${WORKSPACE}/workspace/bld/bld-knife-input/requestor.txt
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
    copyAndExtractBuildArtifactsFromProject() {
        mockedCommand "copyAndExtractBuildArtifactsFromProject $@"
    }
    runOnMaster() {
        mockedCommand "runOnMaster $@"
    }
    mustHaveLocationForSpecialBuild() {
        mockedCommand "mustHaveLocationForSpecialBuild $@"
    }

}
oneTimeTearDown() {
    true
}

setUp() {
    rm -rf ${UT_MOCKED_COMMANDS}
    export LFS_CI_GLOBAL_USECASE=LFS_KNIFE_PACKAGE
    export LFS_CI_CONFIG_FILE=${LFS_CI_ROOT}/etc/lfs-ci.cfg
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
    export LFS_CI_GLOBAL_LOCATION_NAME=location_name

    assertTrue "usecase_LFS_KNIFE_PACKAGE"

    local expect=$(createTempFile)

# getUsedSdkVersions 
# execute tar -rv --transform=s:^\./:sdk3/: -C /build/home/CI_LFS/SDKs/SDK1/ -f ${WORKSPACE}/workspace/lfs-knife.tar .
# execute tar -rv --transform=s:^\./:sdk3/: -C /build/home/CI_LFS/SDKs/SDK2/ -f ${WORKSPACE}/workspace/lfs-knife.tar .
# execute mkdir -p ${WORKSPACE}/workspace/bld/

cat <<EOF > ${expect}
mustHaveLocationForSpecialBuild 
ci_job_package 
copyAndExtractBuildArtifactsFromProject upstream_project 123 knife fsmci
mustHaveNextCiLabelName 
execute touch ${WORKSPACE}/workspace/.00_README.txt
execute tar -cv --transform=s:^\./:os/: -C ${WORKSPACE}/workspace/upload/ -f ${WORKSPACE}/workspace/KNIFE_LABEL.tgz --use-compress-program=${LFS_CI_ROOT}/bin/pigz .
uploadKnifeToStorage ${WORKSPACE}/workspace/KNIFE_LABEL.tgz
copyFileToArtifactDirectory ${WORKSPACE}/workspace/.00_README.txt
execute ${LFS_CI_ROOT}/bin/sendReleaseNote -r ${WORKSPACE}/workspace/.00_README.txt -t KNIFE_LABEL -n -T OS -P LFS -L location_name -f ${LFS_CI_ROOT}/etc/lfs-ci.cfg
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0

