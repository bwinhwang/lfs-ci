#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_database}   ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      ADMIN_HWSWID_DB2TXT()
#  @brief   usecase Admin - create HwSwId.txt
#  @param   <none>
#  @return  <none>
usecase_ADMIN_HWSWID_DB2TXT() {

    requiredParameters JOB_NAME

    local WORKDIR=$(getConfig LFS_CI_HWSWID_WORKDIR)

    rm -rf ${WORKDIR}
    mkdir -p ${WORKDIR}
    cd ${WORKDIR}

    createHwSwIdTxtFile

    #setBuildDescription ${JOB_NAME} ${BUILD_NUMBER} "${JENKINS_JOB_NAME}"

    return
}

## @fn      createHwSwIdTxtFile
#  @brief   
#  @param   <none>
#  @return  <none>
createHwSwIdTxtFile() {
    local MYSQL_TABLE_FSMR3=$(getConfig LFS_CI_HWSWID_DB_TABLE -t hw_platform:fsmr3)
    local MYSQL_TABLE_FSMR4=$(getConfig LFS_CI_HWSWID_DB_TABLE -t hw_platform:fsmr4)

    # FSM-r3 for firmwaretype
    for firmewaretype in $(getConfig LFS_CI_HWSWID_FIRMWARETYPE_FSMR3)
    do
        datafrommysql HwSwId_${firmewaretype}.txt "firmwaretype=\"${firmewaretype}\""  "$MYSQL_TABLE_FSMR3"
    done

    # FSM-r4 for firmwaretype
    for firmewaretype in $(getConfig LFS_CI_HWSWID_FIRMWARETYPE_FSMR4)
    do
        datafrommysql HwSwId_${firmewaretype}.txt  "firmwaretype=\"${firmewaretype}\""  "$MYSQL_TABLE_FSMR4"
    done

    # FSM-r3 for basebandfpga
    for basebandfpga in $(getConfig LFS_CI_HWSWID_BASEBANDFPGA_FSMR3)
    do
        datafrommysql HwSwId_${basebandfpga}.txt "basebandfpga=\"${basebandfpga}\""  "$MYSQL_TABLE_FSMR3"
    done

    datafrommysql HwSwId_UBOOT.txt  'boardname != "FSPN" and boardname != "FIFC"'  "$MYSQL_TABLE_FSMR3"
    removeminor HwSwId_UBOOT.txt
    showtable HwSwId_UBOOT.txt

    datafrommysql HwSwId_UBOOT_FSMR4.txt  '1=1'  "$MYSQL_TABLE_FSMR4"
    removeminor HwSwId_UBOOT_FSMR4.txt
    showtable HwSwId_UBOOT_FSMR4.txt

    datafrommysql HwSwId_UBOOT_FSMR4_FCT.txt  'boardname = "FCTJ" or boardname = "FSCA"'  "$MYSQL_TABLE_FSMR4"
    removeminor HwSwId_UBOOT_FSMR4_FCT.txt
    showtable HwSwId_UBOOT_FSMR4_FCT.txt

    datafrommysql HwSwId_UBOOT_FSMR4_FSP.txt  'boardname like "FSP%"'  "$MYSQL_TABLE_FSMR4"
    removeminor HwSwId_UBOOT_FSMR4_FSP.txt
    showtable HwSwId_UBOOT_FSMR4_FSP.txt

    datafrommysql HwSwId_FSPN.txt  'boardname = "FSPN"'  "$MYSQL_TABLE_FSMR3"
    removeminor HwSwId_FSPN.txt
    showtable HwSwId_FSPN.txt
}

## @fn      datafrommysql
#  @brief   
#  @param   <none>
#  @return  <none>
datafrommysql() {
    local WORKDIR=$(getConfig LFS_CI_HWSWID_WORKDIR)

    #local MYSQL_USER=$(getConfig LFS_CI_HWSWID_DB_USER)
    #local MYSQL_HOST=$(getConfig LFS_CI_HWSWID_DB_HOST)
    #local MYSQL_PASSWORD=$(getConfig LFS_CI_HWSWID_DB_PASSWORD)
    #local MYSQL=$(getConfig LFS_CI_HWSWID_DB_MYSQL)

    export databaseName=hwswid_database
    mustHaveDatabaseCredentials

    local TABLENAME="$1"
    local QUERY="$2"
    local CURRENT_MYSQL_TABLE="$3"

    #echo creating "$TABLENAME" using MYSQL query "$QUERY" in "$WORKDIR" '(MYSQL '$MYSQL_USER@$MYSQL_HOST table $TABLENAME')'
    #echo +++ "$MYSQL" -u"$MYSQL_USER" -h"$MYSQL_HOST" --password="$MYSQL_PASSWORD" -B -r -s -e 'SELECT DISTINCT `hw-sw-id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY"
    #"$MYSQL" -u"$MYSQL_USER" -h"$MYSQL_HOST" --password="$MYSQL_PASSWORD" -B -r -s -e 'SELECT DISTINCT `hw-sw-id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY" >"$TABLENAME".tmp

    info execute ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw-sw-id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY" >"$TABLENAME".tmp
    execute ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw-sw-id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY" >"$TABLENAME".tmp

    #cat "$TABLENAME".tmp | grep -v '^$' | grep -v 'NULL' | sort -u >"$TABLENAME"
    execute grep -v -e '^$' -e 'NULL'  $TABLENAME.tmp | sort -u >"$TABLENAME"
    execute rm "$TABLENAME.tmp"

    rawDebug ${TABLENAME}
}

## @fn      showtable
#  @brief   
#  @param   <none>
#  @return  <none>
showtable() {
    local TABLENAME=${1}

    rawDebug $TABLENAME
}

## @fn      removeminor
#  @brief   
#  @param   <none>
#  @return  <none>
removeminor() {
    local HWSWID="$1"

    sed -e 's/..$/01/' "$HWSWID" | sort -u  >"$HWSWID".new
    mv "$HWSWID".new "$HWSWID"
}

