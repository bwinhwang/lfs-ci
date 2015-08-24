#!/bin/bash

source test/common.sh
source lib/uc_admin_mysql_backup.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        echo $1
    }
    execute() {
        mockedCommand "execute $@"
        [[ $1 == mkdir ]] && $@
        [[ $1 == cd    ]] && $@
        return
    }
    mustHaveDatabaseCredentials() {
        mockedCommand "mustHaveDatabaseCredentials $@"
        dbHost=dbHost
        dbPass=dbPass
        dbUser=dbUser
        dbPort=dbPort
        dbName=dbName
    }
    return
}

setUp() {
    cp -f /dev/null ${UT_MOCKED_COMMANDS}
    export HOME=$(createTempDirectory)
    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    dbHost= dbName= dbPass= dbUser= dbPort=
    unset dbHost dbName dbPass dbUser dbPort
    return
}

test1() {
    assertTrue "usecase_ADMIN_MYSQL_BACKUP"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveDatabaseCredentials 
execute mkdir -p ${HOME}/mysql_backup
execute cd ${HOME}/mysql_backup
execute git init
execute ssh dbHost mysqldump -h dbHost -u dbUser -pdbPass --routines dbName --result-file=${HOME}/mysql_backup/dump.sql
execute git add dump.sql
execute git commit -q -m backup 
execute git gc -q
EOF
    assertExecutedCommands ${expect}

    return
}

test2() {
    mkdir -p ${HOME}/mysql_backup/.git

    assertTrue "usecase_ADMIN_MYSQL_BACKUP"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
mustHaveDatabaseCredentials 
execute mkdir -p ${HOME}/mysql_backup
execute cd ${HOME}/mysql_backup
execute ssh dbHost mysqldump -h dbHost -u dbUser -pdbPass --routines dbName --result-file=${HOME}/mysql_backup/dump.sql
execute git add dump.sql
execute git commit -q -m backup 
execute git gc -q
EOF
    assertExecutedCommands ${expect}

    return
}

source lib/shunit2

exit 0
