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
    copyImportantNoteFilesFromSubversionToWorkspace() {
        mockedCommand "copyImportantNoteFilesFromSubversionToWorkspace $@"
        if [[ ${UT_IMPORTANT_NOTE} ]] ; then
            touch ${WORKSPACE}/workspace/importantNote.txt
        else
            rm -rf ${WORKSPACE}/workspace/importantNote.txt
        fi
    }
    _createLfsOsReleaseNote() {
        mockedCommand "_createLfsOsReleaseNote $@"
    }
    _createLfsRelReleaseNoteXml() {
        mockedCommand "_createLfsRelReleaseNoteXml $@"
    }
    createReleaseInWorkflowTool() {
        mockedCommand "createReleaseInWorkflowTool $@"
    }
    uploadToWorkflowTool() {
        mockedCommand "uploadToWorkflowTool $@"
    }
    _copyFileToBldDirectory() {
        mockedCommand "_copyFileToBldDirectory $@"
    }
    isPatchedRelease() {
        mockedCommand "isPatchedRelease $@"
        return ${UT_IS_PATCHED}
    }
    handlePatchedRelease() {
        mockedCommand "handlePatchedRelease $@"
    }
    addImportantNoteFromPatchedBuild() {
        mockedCommand "addImportantNoteFromPatchedBuild $@"
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
    export UT_IS_PATCHED=0
    assertTrue "_workflowToolCreateRelease"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyImportantNoteFilesFromSubversionToWorkspace 
isPatchedRelease 
addImportantNoteFromPatchedBuild 
_createLfsOsReleaseNote 
createReleaseInWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml release_with_restrictions
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/releasenote.txt
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/changelog.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/revisions.txt
handlePatchedRelease 
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/os_releasenote.xml lfs_os_releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/releasenote.txt lfs_os_releasenote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/changelog.xml lfs_os_changelog.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/revisions.txt revisions.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/importantNote.txt importantNote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents externalComponents.txt
_createLfsRelReleaseNoteXml 
createReleaseInWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml release_with_restrictions
uploadToWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/rel/releasenote.xml lfs_rel_releasenote.xml
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_IS_PATCHED=1
    assertTrue "_workflowToolCreateRelease"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyImportantNoteFilesFromSubversionToWorkspace 
isPatchedRelease 
_createLfsOsReleaseNote 
createReleaseInWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/releasenote.txt
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/changelog.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/revisions.txt
handlePatchedRelease 
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/os_releasenote.xml lfs_os_releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/releasenote.txt lfs_os_releasenote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/changelog.xml lfs_os_changelog.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/revisions.txt revisions.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/importantNote.txt importantNote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents externalComponents.txt
_createLfsRelReleaseNoteXml 
createReleaseInWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml
uploadToWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/rel/releasenote.xml lfs_rel_releasenote.xml
EOF
    assertExecutedCommands ${expect}

    return
}

test3_UBOOT() {
    export UT_IS_PATCHED=1
    export JOB_NAME=UBOOT_Prod_-_UBOOT_-_Release
    assertTrue "_workflowToolCreateRelease"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyImportantNoteFilesFromSubversionToWorkspace 
isPatchedRelease 
_createLfsOsReleaseNote 
createReleaseInWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/releasenote.txt
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/changelog.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/revisions.txt
handlePatchedRelease 
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/os_releasenote.xml lfs_os_releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/releasenote.txt lfs_os_releasenote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/changelog.xml lfs_os_changelog.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/revisions.txt revisions.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/importantNote.txt importantNote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents externalComponents.txt
EOF
    assertExecutedCommands ${expect}

    return
}

test4_important_note() {
    export UT_IS_PATCHED=1
    export UT_IMPORTANT_NOTE=1
    assertTrue "_workflowToolCreateRelease"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyImportantNoteFilesFromSubversionToWorkspace 
isPatchedRelease 
_createLfsOsReleaseNote 
createReleaseInWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/releasenote.txt
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/changelog.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/revisions.txt
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/importantNote.txt
handlePatchedRelease 
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/os_releasenote.xml lfs_os_releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/releasenote.txt lfs_os_releasenote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/changelog.xml lfs_os_changelog.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/revisions.txt revisions.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/importantNote.txt importantNote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents externalComponents.txt
_createLfsRelReleaseNoteXml 
createReleaseInWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml
uploadToWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/rel/releasenote.xml lfs_rel_releasenote.xml
EOF
    assertExecutedCommands ${expect}

    return
}
test4_no_important_note() {
    export UT_IS_PATCHED=1
    export UT_IMPORTANT_NOTE=
    assertTrue "_workflowToolCreateRelease"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
copyImportantNoteFilesFromSubversionToWorkspace 
isPatchedRelease 
_createLfsOsReleaseNote 
createReleaseInWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/os_releasenote.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/releasenote.txt
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/os/changelog.xml
uploadToWorkflowTool PS_LFS_OS_BUILD_NAME ${WORKSPACE}/workspace/revisions.txt
handlePatchedRelease 
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/os_releasenote.xml lfs_os_releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/releasenote.txt lfs_os_releasenote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/os/changelog.xml lfs_os_changelog.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/revisions.txt revisions.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/importantNote.txt importantNote.txt
_copyFileToBldDirectory ${WORKSPACE}/workspace/bld/bld-externalComponents-summary/externalComponents externalComponents.txt
_createLfsRelReleaseNoteXml 
createReleaseInWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml
uploadToWorkflowTool PS_LFS_REL_BUILD_NAME ${WORKSPACE}/workspace/rel/releasenote.xml
_copyFileToBldDirectory ${WORKSPACE}/workspace/rel/releasenote.xml lfs_rel_releasenote.xml
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
