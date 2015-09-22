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
    HwSwIdToSubVersion

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
        datafrommysql HwSwId_${basebandfpga}.txt "basebandfpga=\"${basebandfpga}\""  "$MYSQL_TABLE_FSMR3"
    done

    datafrommysql HwSwId_UBOOT.txt  'boardname != "FSPN" and boardname != "FIFC"'  "$MYSQL_TABLE_FSMR3"
    removeminor HwSwId_UBOOT.txt
    rawDebug "HwSwId_UBOOT.txt"

    datafrommysql HwSwId_UBOOT_FSMR4.txt  '1=1'  "$MYSQL_TABLE_FSMR4"
    removeminor HwSwId_UBOOT_FSMR4.txt
    rawDebug "HwSwId_UBOOT_FSMR4.txt"

    datafrommysql HwSwId_UBOOT_FSMR4_FCT.txt  'boardname = "FCTJ" or boardname = "FSCA"'  "$MYSQL_TABLE_FSMR4"
    removeminor HwSwId_UBOOT_FSMR4_FCT.txt
    rawDebug "HwSwId_UBOOT_FSMR4_FCT.txt"
    datafrommysql HwSwId_UBOOT_FSMR4_FSP.txt  'boardname like "FSP%"'  "$MYSQL_TABLE_FSMR4"
    removeminor HwSwId_UBOOT_FSMR4_FSP.txt
    rawDebug "HwSwId_UBOOT_FSMR4_FSP.txt"

    datafrommysql HwSwId_FSPN.txt  'boardname = "FSPN"'  "$MYSQL_TABLE_FSMR3"
    removeminor HwSwId_FSPN.txt
    rawDebug "HwSwId_FSPN.txt"
}

## @fn      createHwSwIdTxtFile
#  @brief
#  @param   <none>
#  @return  <none>
datafrommysql() {
    local TABLENAME="$1"
    local QUERY="$2"
    local CURRENT_MYSQL_TABLE="$3"
    local WORKDIR=$(getConfig LFS_CI_HWSWID_WORKDIR)

    export databaseName=hwswid_database
    mustHaveDatabaseCredentials

    info creating "$TABLENAME"
    debug creating "$TABLENAME" using MYSQL query "$QUERY" in "$WORKDIR" '(MYSQL '$MYSQL_USER@$MYSQL_HOST table $TABLENAME')'
    debug +++ ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw_sw_id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY" >"$TABLENAME".tmp
    ### dems18x0: 2015-09-22: execute before mysql command is not working !
    ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw_sw_id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY" >"$TABLENAME".tmp

    cat "$TABLENAME".tmp | grep -v '^$' | grep -v 'NULL' | sort -u >"$TABLENAME"
    rm "$TABLENAME.tmp"

    cat $TABLENAME
}


## @fn      removeminor
#  @brief   remove all HwSwId entries not ending with 01
#  @param   <none>
#  @return  <none>
removeminor() {
    local HWSWID="$1"

    sed -e 's/..$/01/' "$HWSWID" | sort -u  >"$HWSWID".new
    mv "$HWSWID".new "$HWSWID"
}


## @fn      HwSwIdToSubVersion
#  @brief   merge created HwSwId.txt from DB with SVN file and do upload to SVN
#  @param   <none>
#  @return  <none>
HwSwIdToSubVersion() {
    local WORKDIR=$(getConfig LFS_CI_HWSWID_WORKDIR)
    local SVNWORKDIR=/home/dems18x0/tmp/HwSwId.SVN

    for URL in $(getConfig LFS_CI_HWSWID_URLS)
    do
        info Writing HwSwId to URL ${URL} ...

        # Check if there is a HwSwId_* file at this URL
        local HWSWIDFOUND=false
        local TMPFILE=$(mktemp /tmp/HwSwId1.XXXXXXXX)
        svn list "$URL" >"$TMPFILE"

        while read FILENAME
        do
            case "$FILENAME"
            in HwSwId_*.txt)    HWSWIDFOUND=true
            esac
        done <"$TMPFILE"
        rm -f "$TMPFILE"
        $HWSWIDFOUND || error "$URL: no HwSwId...txt file found"
        rm -rf "$SVNWORKDIR"
        svn co "$URL" "$SVNWORKDIR"

        # Diff generated HwSwId file from DB with downloaded HwSwId file from SVN
        local diff_found=false
        for FILE in "$SVNWORKDIR"/HwSwId*.txt
        do
            FILENAME=$(basename "$FILE")
            [ -f "$WORKDIR"/"$FILENAME" ] || error "$FILENAME" not in current workdir "$WORKDIR"
            diff "$WORKDIR"/"$FILENAME" "$FILE" || {
                diff_found=true
                cp -f "$WORKDIR"/"$FILENAME" "$FILE"
            }
        done

        # if there is a changed hwswid file for that branch then commit it
        if $diff_found
        then
            cd "$SVNWORKDIR"
            svn info | grep "^URL:"
            svn diff
            info TODO ENABLE: svn commit -m "BTSPS-1657 IN psulm: update HwSwId NOJCHK"
            cd -
        fi

    done

    rm -rf "$SVNWORKDIR"
}
