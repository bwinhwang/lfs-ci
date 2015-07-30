#!/bin/bash
## @file uc_admin_mysql_backup.sh
#  @brief usecase ADMIN_MYSQL_BACKUP

[[ -z ${LFS_CI_SOURCE_database} ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_common}   ]] && source ${LFS_CI_ROOT}/lib/common

usecase_ADMIN_MYSQL_BACKUP() {

    mustHaveDatabaseCredentials

    execute mkdir -p ${HOME}/mysql_backup
    execute cd ${HOME}/mysql_backup
    [[ ! -d .git ]] && execute git init
    execute mysqldump -h ${dbHost} -u ${dbUser} -p${dbPass} --routines ${dbName} --result-file=dump.sql 
    execute git add dump.sql 
    execute git commit -q -m "backup $@"
    execute git gc -q

    return 0
}
