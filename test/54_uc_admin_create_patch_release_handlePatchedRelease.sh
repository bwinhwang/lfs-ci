#!/bin/bash

source test/common.sh
source lib/uc_release.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }

    getConfig() {
        mockedCommand "getConfig $@"
        case ${1} in
            LFS_CI_UC_package_copy_to_share_real_location)  echo ${UT_CI_LFS_SHARE} ;;
            *)                                              echo $1
        esac
    }

    uploadToWorkflowTool() {
        mockedCommand "uploadToWorkflowTool$@"
        info uploadToWorkflowTool $@
    }

    return
}

setUp() {
    export workspace=$(createTempDirectory)
    mkdir -p ${workspace}/workspace
    workspace=${workspace}/workspace

    echo "This is an important note" > ${workspace}/importantNote.txt
    echo "=========================" >> ${workspace}/importantNote.txt

    export UT_CI_LFS_SHARE=$(createTempDirectory)
    export releaseLabel="PS_LFS_OS_2015_08_0001"
    export releaseDirectory=${UT_CI_LFS_SHARE}/${releaseLabel}
    export osTagName="dummy_osTagName"
 
    mkdir -p ${releaseDirectory}/os/doc/patched_release/fsmr2_scripts
    mkdir -p ${releaseDirectory}/os/doc/patched_release/fsmr4_scripts
    echo "This is the fsmr2_changeLog" > ${releaseDirectory}/os/doc/patched_release/fsmr2_changeLog.xml
    echo "This is the fsmr4_changeLog" > ${releaseDirectory}/os/doc/patched_release/fsmr4_changeLog.xml
    echo "This is the fsmr2_revisions.txt" > ${releaseDirectory}/os/doc/patched_release/fsmr2_scripts/revisions.txt
    echo "This is the fsmr2_workdir_fsm3_octeon2.sh" > ${releaseDirectory}/os/doc/patched_release/fsmr2_scripts/workdir_fsm3_octeon2.sh
    echo "This is the fsmr4_revisions.txt" > ${releaseDirectory}/os/doc/patched_release/fsmr4_scripts/revisions.txt
    echo "This is the fsmr4_workdir_fsm3_octeon2.sh" > ${releaseDirectory}/os/doc/patched_release/fsmr4_scripts/workdir_fsm3_octeon2.sh 

    cat >>${releaseDirectory}/os/doc/patched_build.xml<<EOF
<patched_build>
  <triggeredBy user="demx2fk3">Bernhard Minks</triggeredBy>
  <build type="base">PS_LFS_OS_2015_01_0001</build>
  <build type="FSM-r2">PS_LFS_OS_2015_01_0000</build>
  <build type="FSM-r4">PS_LFS_OS_2015_01_0004</build>
  <importantNote>
Das ist ein patched build weil FSM-r4 ned geht!
  </importantNote>
</patched_build>
EOF
    #info "importantNoteXML=${releaseDirectory}/os/doc/patched_build.xml"
    #cat ${releaseDirectory}/os/doc/patched_build.xml
    echo "created all neccessary files"
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test_handlePatchedRelease() {

    assertTrue "handlePatchedRelease"

    tree ${UT_CI_LFS_SHARE}
    local fileListFromTest=$(find  ${releaseDirectory}/os/doc -type f)
    local shortFileListFromTest=
    for file in $fileListFromTest ; do
        shortFile=${file##*os/doc/}
        shortFileListFromTest="$shortFileListFromTest $shortFile"
    done
    shortFileListFromTest=$(echo $shortFileListFromTest|tr " " "\n"|sort|tr "\n" " ")
 
    local expectedFileList="patched_build.xml patched_release/fsmr2_changeLog.xml patched_release/fsmr2_scripts/fsmr2_revisions.txt patched_release/fsmr2_scripts/fsmr2_workdir_fsm3_octeon2.sh patched_release/fsmr4_changeLog.xml patched_release/fsmr4_scripts/fsmr4_revisions.txt patched_release/fsmr4_scripts/fsmr4_workdir_fsm3_octeon2.sh"
    expectedFileList=$(echo $expectedFileList|tr " " "\n"|sort|tr "\n" " ")
    assertEquals "${expectedFileList}" "${shortFileListFromTest}" 
}

test_addImportantNoteFromPatchedBuild() {

    assertTrue "addImportantNoteFromPatchedBuild"

    local fileToCompare=$(createTempFile)
    cat > "${fileToCompare}" << EOF
This is an important note
=========================

THIS IS A LFS RELEASE WITH RESTRICTIONS. THIS LFS RELEASE IS PATCHED AND CAN NOT BE REPRODUCED!

This LFS Release uses the following LFS Builds:
base : PS_LFS_OS_2015_01_0001
FSM-r2 : PS_LFS_OS_2015_01_0000
FSM-r4 : PS_LFS_OS_2015_01_0004

Das ist ein patched build weil FSM-r4 ned geht!
EOF

    assertEquals  "$(cat ${fileToCompare}|xargs)" "$(cat ${workspace}/importantNote.txt|xargs)"
}

source lib/shunit2

exit 0
