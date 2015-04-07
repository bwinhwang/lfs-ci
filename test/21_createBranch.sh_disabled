#!/bin/bash

. lib/common.sh
. lib/logging.sh

oneTimeSetUp() {
    export LFS_CI_ROOT="$(pwd)"

    export SRC_BRANCH="SRC_BRANCH_UNIT_TESTING"
    export NEW_BRANCH="FB1408_UNIT_TESTING"
    export DO_DB_INSERT="true"
    export LRC="false"
    export REVISION="123456789"
    export SOURCE_RELEASE="TEST_RELEASE_NAME"
    export ECL_URLS="ECL URLs not set"
    export COMMENT="Test insert from $(basename $0)"

    dbName=$(getConfig MYSQL_db_name)
    dbUser=$(getConfig MYSQL_db_username)
    dbPass=$(getConfig MYSQL_db_password)
    dbHost=$(getConfig MYSQL_db_hostname)
    dbPort=$(getConfig MYSQL_db_port)

    . scripts/createBranch.sh
}

oneTimeTearDown() {
    echo
}

test_dbInsert() {

    dbInsert $NEW_BRANCH

    local sqlString="SELECT branch_name FROM branches WHERE branch_name='${NEW_BRANCH}'"
    branchName=$(echo $sqlString | mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName})
    assertEquals "DB insert failed." ${branchName} ${NEW_BRANCH}

    local sqlString="DELETE FROM branches WHERE branch_name='${NEW_BRANCH}'"
    branchName=$(echo $sqlString | mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName})
    assertNull "DB delete failed." "${branchName}"
}

test_dbInsert_LRC() {

    export LRC="true"
    dbInsert $NEW_BRANCH

    local sqlString="SELECT branch_name FROM branches WHERE branch_name='LRC_${NEW_BRANCH}'"
    branchName=$(echo $sqlString | mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName})
    assertEquals "DB insert failed." ${branchName} "LRC_${NEW_BRANCH}"

    local sqlString="DELETE FROM branches WHERE branch_name='${NEW_BRANCH}'"
    branchName=$(echo $sqlString | mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName})
    assertNull "DB delete failed." "${branchName}"
}

test_dbInsert_No() {

    export DO_DB_INSERT="false"
    dbInsert $NEW_BRANCH

    local sqlString="SELECT branch_name FROM branches WHERE branch_name='${NEW_BRANCH}'"
    branchName=$(echo $sqlString | mysql -N -u ${dbUser} --password=${dbPass} -h ${dbHost} -P ${dbPort} -D ${dbName})
    assertNull "DB delete failed." "${branchName}"
}


. lib/shunit2
