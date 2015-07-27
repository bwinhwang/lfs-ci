#!/bin/bash

source test/common.sh
source lib/uc_admin_svn_clone.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    execute() {
        mockedCommand "execute $@"
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    mustExistDirectory() {
        mockedCommand "mustExistDirectory $@"
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
    assertTrue "usecase_ADMIN_CLONE_SVN"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig ADMIN_lfs_svn_clone_master_directory
mustExistDirectory ADMIN_lfs_svn_clone_master_directory
execute svnsync sync file://ADMIN_lfs_svn_clone_master_directory/
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    assertTrue "usecase_ADMIN_RESTORE_SVN_CLONE"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig ADMIN_lfs_svn_clone_master_directory
mustExistDirectory ADMIN_lfs_svn_clone_master_directory
getConfig ADMIN_lfs_svn_clone_working_directory
execute mkdir -p ADMIN_lfs_svn_clone_working_directory
execute rsync --delete -avrP ADMIN_lfs_svn_clone_master_directory/. ADMIN_lfs_svn_clone_working_directory/.
EOF
    assertExecutedCommands ${expect}

    return
}
source lib/shunit2

exit 0