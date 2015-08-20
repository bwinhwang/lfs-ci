#!/bin/bash
## @file uc_admin_mysql_backup.sh
#  @brief usecase ADMIN_MYSQL_BACKUP

[[ -z ${LFS_CI_SOURCE_database} ]] && source ${LFS_CI_ROOT}/lib/database.sh
[[ -z ${LFS_CI_SOURCE_common}   ]] && source ${LFS_CI_ROOT}/lib/common

## @fn      usecase_ADMIN_MYSQL_BACKUP()
#  @brief   run usecase ADMIN_MYSQ_BACKUP
#  @details dumping the database into a file called dump.sql and store it
#           (uncompressed) in git. So we can store several 1000 versions
#           without wasting too much space on the harddisk.
#           15000 versions need 3.7 GB.
#  @param   <none>
#  @return  <none>
usecase_ADMIN_MYSQL_BACKUP() {
    requiredParameters HOME

    mustHaveDatabaseCredentials

    execute mkdir -p ${HOME}/mysql_backup
    execute cd ${HOME}/mysql_backup
    [[ ! -d .git ]] && execute git init

    # there is a problem between the version of mysqldump on the database server and the client (here master).
    # see https://bugs.mysql.com/bug.php?id=66765
    # workaround: run mysqldump on the database host
    execute ssh ${dbHost} mysqldump -h ${dbHost} -u ${dbUser} -p${dbPass} --routines ${dbName} --result-file=${HOME}/mysql_backup/dump.sql 
    execute git add dump.sql 
    execute git commit -q -m "backup $@"
    execute git gc -q

    return 0
}


## @fn      usecase_ADMIN_MYSQL_RESTORE()
#  @brief   usecase restore mysql database from backup
#  @param   <none>
#  @return  <none>
usecase_ADMIN_MYSQL_RESTORE() {
    requiredParameters HOME

    mustHaveDatabaseCredentials

    # there is a problem between the version of mysqldump on the database server and the client (here master).
    # see https://bugs.mysql.com/bug.php?id=66765
    # workaround: run mysqldump on the database host

    execute ssh ${dbHost} mysql -h ${dbHost} -u ${dbUser} -p${dbPass} ${dbName} < ${LFS_CI_ROOT}/database/drop.sql 
    execute ssh ${dbHost} mysql -h ${dbHost} -u ${dbUser} -p${dbPass} ${dbName} < ${HOME}/mysql_backup/dump.sql 
    return 0
}
