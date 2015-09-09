#!/bin/bash

source test/common.sh
source lib/uc_admin_create_patch_release.sh

oneTimeSetUp() {
    export BASE_BUILD=PS_LFS_OS_2015_08_0001
    export FSMR2_PATCH_BUILD=PS_LFS_OS_2015_08_0002
    export FSMR3_PATCH_BUILD=PS_LFS_OS_2015_08_0002
    export FSMR4_PATCH_BUILD=
    export IMPORTANT_NOTE='Kilroy was here'
    export BUILD_USER_ID=123456
    export BUILD_USER=Kilroy

    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }


    getConfig() {
        mockedCommand "getConfig $@"
        case ${1} in
            LFS_CI_UC_package_copy_to_share_name)           echo ${UT_CI_LFS_SHARE} ;;
            LFS_CI_UC_package_copy_to_share_real_location)  echo ${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3 ;;
            LFS_PROD_tag_to_branch)                         echo trunk ;;
            LFS_hw_platforms)                               echo fsmr2 fsmr3 fsmr4 ;;
            LFS_release_os_subdir)                          echo os/sys-root/subdir/x86_64-pc-linux-gnu ;;
            *)                                              echo $1
        esac
    }

    getPackageBuildNumberFromFingerprint() {
        mockedCommand "getPackageBuildNumberFromFingerprint $@"
        if [[ "${1}" == "PS_LFS_OS_2015_08_01_9999" ]] ; then
            exit 1
        else
            echo 1234
        fi
    }

    getPackageJobNameFromFingerprint() {
        mockedCommand "getPackageJobNameFromFingerprint $@"
        echo LFS_CI_-_trunk_-_Package_-_package
        return
    }

    copyChangelogToWorkspace() {
        mockedCommand "copyChangelogToWorkspace $@"
        info calling mocked command copyChangelogToWorkspace
        echo blabla > ${WORKSPACE}/changelog.xml
        return
    }
        

    return
}

setUp() {
    export UT_CI_LFS_SHARE=$(createTempDirectory)
    export RELEASE_DIR=${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0001
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    mkdir -p ${RELEASE_DIR}/os/doc/scripts
    mkdir -p ${RELEASE_DIR}/os/sys-root/subdir
    export PATCHED_BUILD=${RELEASE_DIR}/os/doc/patched_build.xml
    mkdir -p ${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0002/os/doc/scripts
    mkdir -p ${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0002/os/sys-root/subdir/x86_64-pc-linux-gnu
    # let PS_LFS_OS_2015_08_0002 already be released
    mkdir -p ${UT_CI_LFS_SHARE}/Release
    ln -s ${UT_CI_LFS_SHARE}/Release_Candidates/FSMr3/PS_LFS_OS_2015_08_0002 ${UT_CI_LFS_SHARE}/Release/PS_LFS_REL_2015_08_0002
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}
    export FILE_TO_COMPARE=${WORKSPACE}/impnote.xml
    cat > ${FILE_TO_COMPARE} << EOF
THIS IS A LFS RELEASE WITH RESTRICTIONS. THIS LFS RELEASE IS PATCHED AND CAN NOT BE REPRODUCED! This LFS Release uses the following LFS Builds: base : PS_LFS_OS_2015_08_0001 FSM-r2 : PS_LFS_OS_2015_08_0002 FSM-r3 : PS_LFS_OS_2015_08_0002 Kilroy was here
EOF
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    rm -rf ${UT_CI_LFS_SHARE}
    rm -rf ${WORKSPACE}
    return
}

test1() {
    for func in mustHaveAllBuilds \
                mustDifferFromBaseBuild \
                mustHaveAllBuildsOfSameBranch \
                mustHaveOneEmptyPatchBuild \
                mustHaveMinimumOnePatchBuild \
                mustHaveNoNestedPatchBuild \
                mustBeUnreleasedBaseBuild \
                mustHaveFinishedAllPackageJobs \
                markBaseBuildAsPatched \
                copyPatchBuildsIntoBaseBuild
    do
        info now executing ${func} ...
        assertTrue "${func} failed!" "${func}"
    done

    checkForFilesAndDirs

    return
}

test2() {
    assertTrue "usecase_ADMIN_CREATE_PATCH_RELEASE failed!" "usecase_ADMIN_CREATE_PATCH_RELEASE"

    checkForFilesAndDirs

    return
}

checkForFilesAndDirs() {
    # check that required files have been created
    assertTrue ".../os/doc/patched_build.xml not found!"                              "[[ -f ${RELEASE_DIR}/os/doc/patched_build.xml ]]"
    assertTrue "... /os/doc/patched_release/fsmr2_changelog.xml not found!"           "[[ -f  ${RELEASE_DIR}/os/doc/patched_release/fsmr2_changelog.xml ]]"
    assertTrue "... /os/doc/patched_release/fsmr3_changelog.xml not found!"           "[[ -f  ${RELEASE_DIR}/os/doc/patched_release/fsmr3_changelog.xml ]]"
    assertTrue "${RELEASE_DIR}/os/doc/patched_release/fsmr2_scripts not found!"       "[[ -d  ${RELEASE_DIR}/os/doc/patched_release/fsmr2_scripts ]]"
    assertTrue "${RELEASE_DIR}/os/doc/patched_release/fsmr3_scripts not found!"       "[[ -d  ${RELEASE_DIR}/os/doc/patched_release/fsmr3_scripts ]]"
    assertTrue "${RELEASE_DIR}/os/sys-root/subdir/x86_64-pc-linux-gnu not found!"     "[[ -d  ${RELEASE_DIR}/os/sys-root/subdir/x86_64-pc-linux-gnu ]]"

    # check for important note
    local impnote=$(xsltproc                                          \
                    ${LFS_CI_ROOT}/lib/contrib/patchedImportantNote.xslt \
                    ${PATCHED_BUILD})

    assertEquals "$(cat ${FILE_TO_COMPARE})" "$(echo ${impnote})"

    return
}


source lib/shunit2

exit 0
