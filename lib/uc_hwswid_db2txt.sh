#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_database}   ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      HWSWID_DB2TXT()
#  @brief   usecase create HwSwId.txt out of database
#  @param   <none>
#  @return  <none>
usecase_HWSWID_DB2TXT() {
    requiredParameters JOB_NAME

    export workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    export hwswidWorkdirDb=${workspace}/HwSwId.DB
    mustHaveValue "${hwswidWorkdirDb}" "hwswidWorkdirDb"
    mkdir -p ${hwswidWorkdirDb}
    cd ${hwswidWorkdirDb}

    createHwSwIdTxtFile
    HwSwIdToSubVersion

    return
}

## @fn      createHwSwIdTxtFile
#  @brief   create intermediate HwSwId_<firmware>.txt files out of the database
#  @param   <none>
#  @return  <none>
createHwSwIdTxtFile() {
    local mysqlTableFsmr3=$(getConfig LFS_CI_HWSWID_DB_TABLE -t hw_platform:fsmr3)
    mustHaveValue "${mysqlTableFsmr3}" "mysqlTableFsmr3"
    local mysqlTableFsmr4=$(getConfig LFS_CI_HWSWID_DB_TABLE -t hw_platform:fsmr4)
    mustHaveValue "${mysqlTableFsmr4}" "mysqlTableFsmr4"

    # FSM-r{3,4} for firmewaretype
    for hw_platform in fsmr3 fsmr4
    do
        for firmewaretype in $(getConfig LFS_CI_HWSWID_FIRMWARETYPE -t hw_platform:${hw_platform})
        do
            datafrommysql HwSwId_${firmewaretype}.txt "firmwaretype=\"${firmewaretype}\""  "$(getConfig LFS_CI_HWSWID_DB_TABLE -t hw_platform:${hw_platform})"
        done
    done

    # FSM-r3 for basebandfpga
    for basebandfpga in $(getConfig LFS_CI_HWSWID_BASEBANDFPGA -t hw_platform:fsmr3)
    do
        datafrommysql HwSwId_${basebandfpga}.txt "basebandfpga=\"${basebandfpga}\""  "$mysqlTableFsmr3"
    done

    datafrommysql HwSwId_UBOOT.txt  'boardname != "FSPN" and boardname != "FIFC"'  "$mysqlTableFsmr3"
    removeminor HwSwId_UBOOT.txt
    rawDebug "HwSwId_UBOOT.txt"

    datafrommysql HwSwId_UBOOT_FSMR4.txt  '1=1'  "$mysqlTableFsmr4"
    removeminor HwSwId_UBOOT_FSMR4.txt
    rawDebug "HwSwId_UBOOT_FSMR4.txt"

    datafrommysql HwSwId_UBOOT_FSMR4_FCT.txt  'boardname = "FCTJ" or boardname = "FSCA"'  "$mysqlTableFsmr4"
    removeminor HwSwId_UBOOT_FSMR4_FCT.txt
    rawDebug "HwSwId_UBOOT_FSMR4_FCT.txt"
    datafrommysql HwSwId_UBOOT_FSMR4_FSP.txt  'boardname like "FSP%"'  "$mysqlTableFsmr4"
    removeminor HwSwId_UBOOT_FSMR4_FSP.txt
    rawDebug "HwSwId_UBOOT_FSMR4_FSP.txt"

    datafrommysql HwSwId_FSPN.txt  'boardname = "FSPN"'  "$mysqlTableFsmr3"
    removeminor HwSwId_FSPN.txt
    rawDebug "HwSwId_FSPN.txt"
}

## @fn      createHwSwIdTxtFile
#  @brief   execute sql command to create intermediate HwSwId_<firmware>.txt files out of the database
#  @param   HwSwId_xxx.txt file
#  @param   sql where clause
#  @param   mysql table name
#  @return  <none>
datafrommysql() {
    local hwswidTxtFile="$1"
    mustHaveValue "${hwswidTxtFile}" "hwswidTxtFile"
    local query="$2"
    mustHaveValue "${query}" "query"
    local currentMysqlTable="$3"
    mustHaveValue "${currentMysqlTable}" "currentMysqlTable"

    export databaseName=hwswid_database
    mustHaveDatabaseCredentials

    info creating "$hwswidTxtFile"
    debug creating "$hwswidTxtFile" using MYSQL query "$query" in "${hwswidWorkdirDb}" '(MYSQL '$MYSQL_USER@$MYSQL_HOST table $hwswidTxtFile')'
    debug +++ ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw_sw_id` FROM '"$currentMysqlTable"' WHERE '"$query" >"$hwswidTxtFile".tmp
    ### dems18x0: 2015-09-22: execute before mysql command is not working !
    ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw_sw_id` FROM '"$currentMysqlTable"' WHERE '"$query" >"$hwswidTxtFile".tmp

    cat "$hwswidTxtFile".tmp | grep -v '^$' | grep -v 'NULL' | sort -u >"$hwswidTxtFile"
    rm "$hwswidTxtFile.tmp"

    cat $hwswidTxtFile
}


## @fn      removeminor
#  @brief   substitute all latest 2 digits of HwSwId entries 01
#  @param   HwSwId_xxx.txt file
#  @return  <none>
removeminor() {
    local hwswidTxtFile="$1"
    mustHaveValue "${hwswidTxtFile}" "hwswidTxtFile"

    sed -e 's/..$/01/' "${hwswidTxtFile}" | sort -u  >"${hwswidTxtFile}".new
    mv "${hwswidTxtFile}".new "${hwswidTxtFile}"
}


## @fn      HwSwIdToSubVersion
#  @brief   merge created HwSwId.txt from DB with SVN file and do upload to SVN if chnaged
#  @param   <none>
#  @return  <none>
HwSwIdToSubVersion() {
    local hwswidWorkdirSvn=${workspace}/HwSwId.SVN
    mustHaveValue "${hwswidWorkdirSvn}" "hwswidWorkdirSvn"

    for url in $(getConfig LFS_CI_HWSWID_URLS)
    do
        info Writing HwSwId to URL ${url} ...

        # Check if there is a HwSwId_* file at this URL
        local hwswidTxtFound=false
        local tmpfile=$(mktemp /tmp/HwSwId1.XXXXXXXX)
        svn list "${url}" >"${tmpfile}"

        while read filename
        do
            case "${filename}"
            in HwSwId_*.txt)    hwswidTxtFound=true
            esac
        done <"${tmpfile}"
        rm -f "${tmpfile}"
        ${hwswidTxtFound} || error "${url}: no HwSwId...txt file found"
        rm -rf "${hwswidWorkdirSvn}"
        svn co "${url}" "${hwswidWorkdirSvn}"

        # Diff generated HwSwId file from DB with downloaded HwSwId file from SVN
        local diffFound=false
        for FILE in "${hwswidWorkdirSvn}"/HwSwId*.txt
        do
            filename=$(basename "$FILE")
            mustHaveValue "${filename}" "filename"
            [ -f "${hwswidWorkdirDb}"/"${filename}" ] || error "${filename}" not in current workdir "${hwswidWorkdirDb}"
            diff "${hwswidWorkdirDb}"/"${filename}" "$FILE" || {
                diffFound=true
                cp -f "${hwswidWorkdirDb}"/"${filename}" "$FILE"
            }
        done

        # if there is a changed hwswid file for that branch then commit it
        if $diffFound
        then
            cd "${hwswidWorkdirSvn}"
            svn info | grep "^URL:"
            svn diff
            info TODO ENABLE: svn commit -m "BTSPS-1657 IN psulm: update HwSwId NOJCHK"
            cd -
        else
            info No HwSwId changes in ${url}
        fi

    done

    rm -rf "${hwswidWorkdirSvn}"
}
