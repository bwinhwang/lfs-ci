#!/bin/bash

source test/common.sh
source lib/uc_admin.sh

oneTimeSetUp() {
    mockedCommand() {
        echo "$@" >> ${UT_MOCKED_COMMANDS}
    }
    getConfig() {
        mockedCommand "getConfig $@"
        case $1 in
            jenkinsMasterServerBackupPath) echo ${UT_BACKUP_PATH} ;;
            *) echo $1 ;;
        esac
    }
    execute() {
        mockedCommand "execute $@"
        return
    }
    return
}

setUp() {
    cat /dev/null > ${UT_MOCKED_COMMANDS}
    export UT_BACKUP_PATH=$(createTempDirectory)

    return
}

tearDown() {
    rm -rf ${UT_MOCKED_COMMANDS}
    dbHost= dbName= dbPass= dbUser= dbPort=
    unset dbHost dbName dbPass dbUser dbPort
    return
}

test1() {
    assertTrue "backupJenkinsMasterServerInstallation"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig jenkinsMasterServerBackupPath
getConfig jenkinsMasterServerPath
execute rm -rf ${UT_BACKUP_PATH}/backup.11
execute mkdir -p ${UT_BACKUP_PATH}/backup.0/
execute rsync -av --delete --delete-excluded --exclude=workspace --exclude=htmlreports jenkinsMasterServerPath/. ${UT_BACKUP_PATH}/backup.0/.
execute touch ${UT_BACKUP_PATH}/backup.0
EOF
    assertExecutedCommands ${expect}

    return
}
test2() {
    mkdir -p ${UT_BACKUP_PATH}/backup.1
    mkdir -p ${UT_BACKUP_PATH}/backup.2
    assertTrue "backupJenkinsMasterServerInstallation"

    local expect=$(createTempFile)
    cat <<EOF > ${expect}
getConfig jenkinsMasterServerBackupPath
getConfig jenkinsMasterServerPath
execute rm -rf ${UT_BACKUP_PATH}/backup.11
execute mv -f ${UT_BACKUP_PATH}/backup.2 ${UT_BACKUP_PATH}/backup.3
execute mv -f ${UT_BACKUP_PATH}/backup.1 ${UT_BACKUP_PATH}/backup.2
execute cp -rl ${UT_BACKUP_PATH}/backup.1 ${UT_BACKUP_PATH}/backup.0
execute rsync -av --delete --delete-excluded --exclude=workspace --exclude=htmlreports jenkinsMasterServerPath/. ${UT_BACKUP_PATH}/backup.0/.
execute touch ${UT_BACKUP_PATH}/backup.0
EOF
    assertExecutedCommands ${expect}

    return
}


source lib/shunit2

exit 0
