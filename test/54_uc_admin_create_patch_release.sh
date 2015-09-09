#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    mustHaveAllBuilds() {
        mockedCommand "mustHaveAllBuilds $@"
    }

    mustDifferFromBaseBuild() {
        mockedCommand "mustDifferFromBaseBuild $@"
    }

    mustHaveAllBuildsOfSameBranch() {
        mockedCommand "mustHaveAllBuildsOfSameBranch $@"
    }

    mustHaveOneEmptyPatchBuild() {
        mockedCommand "mustHaveOneEmptyPatchBuild $@"
    }

    mustHaveMinimumOnePatchBuild() {
        mockedCommand "mustHaveMinimumOnePatchBuild $@"
    }

    mustHaveNoNestedPatchBuild() {
        mockedCommand "mustHaveNoNestedPatchBuild $@"
    }

    mustBeUnreleasedBaseBuild() {
        mockedCommand "mustBeUnreleasedBaseBuild $@"
    }

    mustHaveFinishedAllPackageJobs() {
        mockedCommand "mustHaveFinishedAllPackageJobs $@"
    }

    markBaseBuildAsPatched() {
        mockedCommand "markBaseBuildAsPatched $@"
    }

    copyPatchBuildsIntoBaseBuild() {
        mockedCommand "copyPatchBuildsIntoBaseBuild $@"
    } 

    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export BASE_BUILD="PS_LFS_OS_2015_08_01_001"
    export FSMR2_PATCH_BUILD="PS_LFS_OS_2015_08_01_002"
    export FSMR3_PATCH_BUILD="PS_LFS_OS_2015_08_01_003"
    export IMPORTANT_NOTE="BlaBla"
    export BUILD_USER_ID=1234
    export BUILD_USER="User1"
    assertTrue "usecase_ADMIN_CREATE_PATCH_RELEASE finished with failure!" "usecase_ADMIN_CREATE_PATCH_RELEASE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveAllBuilds 
mustDifferFromBaseBuild 
mustHaveAllBuildsOfSameBranch 
mustHaveOneEmptyPatchBuild 
mustHaveMinimumOnePatchBuild 
mustHaveNoNestedPatchBuild 
mustBeUnreleasedBaseBuild 
mustHaveFinishedAllPackageJobs 
markBaseBuildAsPatched 
copyPatchBuildsIntoBaseBuild 
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
