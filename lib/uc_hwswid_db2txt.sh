#!/bin/bash

[[ -z ${LFS_CI_SOURCE_common}     ]] && source ${LFS_CI_ROOT}/lib/common.sh
[[ -z ${LFS_CI_SOURCE_jenkins}    ]] && source ${LFS_CI_ROOT}/lib/jenkins.sh
[[ -z ${LFS_CI_SOURCE_database}   ]] && source ${LFS_CI_ROOT}/lib/database.sh

## @fn      HWSWID_DB2TXT()
#  @brief   usecase create HwSwId.txt out of database
#  @param   <none>
#  @return  <none>
usecase_HWSWID_DB2TXT() {
    export workspace=$(getWorkspaceName)
    mustHaveWorkspaceName
    mustHaveCleanWorkspace

    export hwswidWorkdirDb=${workspace}/HwSwId.DB
    mkdir -p ${hwswidWorkdirDb}
    cd ${hwswidWorkdirDb}

    createHwSwIdTxtFile
    hwSwIdToSubVersion

    return 0
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
            local sglWhereSubPart="firmwaretype=\"${firmewaretype}\" OR firmwaretype LIKE \"%${firmewaretype}#%\" OR firmwaretype LIKE \"%#${firmewaretype}\""
            debug +++ sglWhereSubPart="${sglWhereSubPart}"
            hwswidDataFromMysql HwSwId_${firmewaretype}.txt "${sglWhereSubPart}"  "$(getConfig LFS_CI_HWSWID_DB_TABLE -t hw_platform:${hw_platform})"
        done
    done

    # FSM-r3 for basebandfpga
    for basebandfpga in $(getConfig LFS_CI_HWSWID_BASEBANDFPGA -t hw_platform:fsmr3)
    do
        local sglWhereSubPart="basebandfpga=\"${basebandfpga}\" OR basebandfpga LIKE \"%${basebandfpga}#%\" OR basebandfpga LIKE \"%#${basebandfpga}\""
        debug +++ sglWhereSubPart="${sglWhereSubPart}"
        hwswidDataFromMysql HwSwId_${basebandfpga}.txt "${sglWhereSubPart}"  "$mysqlTableFsmr3"
    done

    hwswidDataFromMysql HwSwId_UBOOT.txt  'boardname != "FSPN" and boardname != "FIFC"'  "$mysqlTableFsmr3"
    hwswidRemoveMinorVersion HwSwId_UBOOT.txt
    rawDebug "HwSwId_UBOOT.txt"

    hwswidDataFromMysql HwSwId_UBOOT_FSMR4.txt  '1=1'  "$mysqlTableFsmr4"
    hwswidRemoveMinorVersion HwSwId_UBOOT_FSMR4.txt
    rawDebug "HwSwId_UBOOT_FSMR4.txt"

    hwswidDataFromMysql HwSwId_UBOOT_FSMR4_FCT.txt  'boardname = "FCTJ" or boardname = "FSCA"'  "$mysqlTableFsmr4"
    hwswidRemoveMinorVersion HwSwId_UBOOT_FSMR4_FCT.txt
    rawDebug "HwSwId_UBOOT_FSMR4_FCT.txt"
    hwswidDataFromMysql HwSwId_UBOOT_FSMR4_FSP.txt  'boardname like "FSP%"'  "$mysqlTableFsmr4"
    hwswidRemoveMinorVersion HwSwId_UBOOT_FSMR4_FSP.txt
    rawDebug "HwSwId_UBOOT_FSMR4_FSP.txt"

    hwswidDataFromMysql HwSwId_FSPN.txt  'boardname = "FSPN"'  "$mysqlTableFsmr3"
    hwswidRemoveMinorVersion HwSwId_FSPN.txt
    rawDebug "HwSwId_FSPN.txt"
}

## @fn      hwswidDataFromMysql
#  @brief   execute sql command to create intermediate HwSwId_<firmware>.txt files out of the database
#  @param   HwSwId_xxx.txt file
#  @param   sql where clause
#  @param   mysql table name
#  @return  <none>
hwswidDataFromMysql() {
    local hwswidTxtFile="$1"
    mustHaveValue "${hwswidTxtFile}" "hwswidTxtFile"
    debug +++ hwswidTxtFile="${hwswidTxtFile}"
    local query="$2"
    mustHaveValue "${query}" "query"
    debug +++ query="${query}"
    local currentMysqlTable="$3"
    mustHaveValue "${currentMysqlTable}" "currentMysqlTable"
    debug +++ currentMysqlTable="${currentMysqlTable}"

    export databaseName=hwswid_database
    mustHaveDatabaseCredentials

    info creating "$hwswidTxtFile"
    debug creating "$hwswidTxtFile" using MYSQL query "$query" in "${hwswidWorkdirDb}" '(MYSQL '$MYSQL_USER@$MYSQL_HOST table $hwswidTxtFile')'
    local databaseOutput=$(createTempFile)
    echo "SELECT DISTINCT hw_sw_id FROM $currentMysqlTable WHERE $query" | execute -l ${databaseOutput} ${mysql_cli} -N
    grep -v -e '^$' -e 'NULL' "${databaseOutput}" | sort -u >"$hwswidTxtFile"

    rawDebug $hwswidTxtFile
}


## @fn      hwswidRemoveMinorVersion
#  @brief   substitute all latest 2 digits of HwSwId entries 01
#  @param   HwSwId_xxx.txt file
#  @return  <none>
hwswidRemoveMinorVersion() {
    local hwswidTxtFile="$1"
    mustHaveValue "${hwswidTxtFile}" "hwswidTxtFile"

    sed -e 's/..$/01/' "${hwswidTxtFile}" | sort -u  >"${hwswidTxtFile}".new
    mv "${hwswidTxtFile}".new "${hwswidTxtFile}"

    return 0
}


## @fn      hwSwIdToSubVersion
#  @brief   merge created HwSwId.txt from DB with SVN file and do upload to SVN if chnaged
#  @param   <none>
#  @return  <none>
hwSwIdToSubVersion() {
    local hwswidWorkdirSvn=${workspace}/HwSwId.SVN

    for url in $(getConfig LFS_CI_HWSWID_URLS)
    do
        info Updating HwSwId when needed to URL ${url} ...

        rm -rf "${hwswidWorkdirSvn}"
        svnCheckout ${url} "${hwswidWorkdirSvn}"
        execute cp -a ${hwswidWorkdirDb}/* "${hwswidWorkdirSvn}"/
        svnDiff ${hwswidWorkdirSvn}
        local msg=$(createTempFile)
        echo "update HwSwId" > ${msg} 
        info TODO: svnCommit -F ${msg} ${hwswidWorkdirSvn}

    done

    return 0
}
