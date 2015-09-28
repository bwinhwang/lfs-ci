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
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export WORKSPACE=$(createTempDirectory)

    mkdir -p ${WORKSPACE}/workspace/
    cd ${WORKSPACE}/workspace
    touch    ${WORKSPACE}/workspace/changelog.xml

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    return
}

test1() {
    assertTrue "_copyFileToBldDirectory changelog.xml c.xml"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-lfs-release
execute cp -f changelog.xml ${WORKSPACE}/workspace/bld/bld-lfs-release/c.xml
EOF
    assertExecutedCommands ${expect}

    return
}
test2() {
    assertTrue "_copyFileToBldDirectory foobar.xml c.xml"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
execute mkdir -p ${WORKSPACE}/workspace/bld/bld-lfs-release
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
