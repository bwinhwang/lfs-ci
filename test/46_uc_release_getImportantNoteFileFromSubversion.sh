#!/bin/bash

source test/common.sh
source lib/uc_release.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
        echo "src-project http://foobar/src-project 12345"
    }
    existsInSubversion() {
        mockedCommand "existsInSubversion $@"
        return ${UT_EXISTS_IN_SVN}
    }
    svnCat() {
        mockedCommand "svnCat $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)
    mkdir -p ${WORKSPACE}/workspace
    touch ${WORKSPACE}/workspace/revisions.txt
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    export UT_EXISTS_IN_SVN=0
    assertTrue "copyImportantNoteFilesFromSubversionToWorkspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_release_important_note_file
execute -n grep ^src-project ${WORKSPACE}/workspace/revisions.txt
execute -n grep ^src-project ${WORKSPACE}/workspace/revisions.txt
existsInSubversion -r 12345 http://foobar/src-project/src release_note
existsInSubversion -r 12345 http://foobar/src-project/src/release_note LFS_uc_release_important_note_file
svnCat -r 12345 http://foobar/src-project/src/release_note/LFS_uc_release_important_note_file@12345
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    export UT_EXISTS_IN_SVN=1
    assertTrue "copyImportantNoteFilesFromSubversionToWorkspace"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig LFS_uc_release_important_note_file
execute -n grep ^src-project ${WORKSPACE}/workspace/revisions.txt
execute -n grep ^src-project ${WORKSPACE}/workspace/revisions.txt
existsInSubversion -r 12345 http://foobar/src-project/src release_note
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0
