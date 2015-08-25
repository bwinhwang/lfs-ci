#!/bin/bash

source test/common.sh
source lib/database.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    dbHost= dbName= dbPass= dbUser= dbPort=
    unset dbHost dbName dbPass dbUser dbPort
    return
}

test1() {
    assertTrue "mustHaveDatabaseCredentials"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig MYSQL_db_name
getConfig MYSQL_db_port
getConfig MYSQL_db_username
getConfig MYSQL_db_password
getConfig MYSQL_db_hostname
EOF
    assertExecutedCommands ${expect}

    mustHaveDatabaseCredentials
    assertEquals "config for db host" "MYSQL_db_hostname" "${dbHost}" 
    assertEquals "config for db port" "MYSQL_db_port"     "${dbPort}" 
    assertEquals "config for db name" "MYSQL_db_name"     "${dbName}" 
    assertEquals "config for db user" "MYSQL_db_username" "${dbUser}" 
    assertEquals "config for db pass" "MYSQL_db_password" "${dbPass}"

    return
}

test2() {
    dbHost=abc

    assertTrue "mustHaveDatabaseCredentials"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig MYSQL_db_name
getConfig MYSQL_db_port
getConfig MYSQL_db_username
getConfig MYSQL_db_password
EOF
    assertExecutedCommands ${expect}

    mustHaveDatabaseCredentials
    assertEquals "config for db host" "abc"               "${dbHost}" 
    assertEquals "config for db port" "MYSQL_db_port"     "${dbPort}" 
    assertEquals "config for db name" "MYSQL_db_name"     "${dbName}" 
    assertEquals "config for db user" "MYSQL_db_username" "${dbUser}" 
    assertEquals "config for db pass" "MYSQL_db_password" "${dbPass}"

    return
}

test3() {
    dbPass=abc

    assertTrue "mustHaveDatabaseCredentials"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig MYSQL_db_name
getConfig MYSQL_db_port
getConfig MYSQL_db_username
getConfig MYSQL_db_hostname
EOF
    assertExecutedCommands ${expect}

    mustHaveDatabaseCredentials
    assertEquals "config for db host" "MYSQL_db_hostname" "${dbHost}" 
    assertEquals "config for db port" "MYSQL_db_port"     "${dbPort}" 
    assertEquals "config for db name" "MYSQL_db_name"     "${dbName}" 
    assertEquals "config for db user" "MYSQL_db_username" "${dbUser}" 
    assertEquals "config for db pass" "abc"               "${dbPass}"

    return
}

test4() {
    dbUser=abc

    assertTrue "mustHaveDatabaseCredentials"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig MYSQL_db_name
getConfig MYSQL_db_port
getConfig MYSQL_db_password
getConfig MYSQL_db_hostname
EOF
    assertExecutedCommands ${expect}

    mustHaveDatabaseCredentials
    assertEquals "config for db host" "MYSQL_db_hostname" "${dbHost}" 
    assertEquals "config for db port" "MYSQL_db_port"     "${dbPort}" 
    assertEquals "config for db name" "MYSQL_db_name"     "${dbName}" 
    assertEquals "config for db user" "abc"               "${dbUser}" 
    assertEquals "config for db pass" "MYSQL_db_password" "${dbPass}"

    return
}

test5() {
    dbPort=abc

    assertTrue "mustHaveDatabaseCredentials"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig MYSQL_db_name
getConfig MYSQL_db_username
getConfig MYSQL_db_password
getConfig MYSQL_db_hostname
EOF
    assertExecutedCommands ${expect}

    mustHaveDatabaseCredentials
    assertEquals "config for db host" "MYSQL_db_hostname" "${dbHost}" 
    assertEquals "config for db port" "abc"               "${dbPort}" 
    assertEquals "config for db name" "MYSQL_db_name"     "${dbName}" 
    assertEquals "config for db user" "MYSQL_db_username" "${dbUser}" 
    assertEquals "config for db pass" "MYSQL_db_password" "${dbPass}"

    return
}
source lib/shunit2

exit 0
