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
    #HwSwIdToSubVersion

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

    for hw_platform in fsmr3 fsmr4
    do
        for firmewaretype in $(getConfig LFS_CI_HWSWID_FIRMWARETYPE -t hw_platform:${hw_platform})
        do
            datafrommysql HwSwId_${firmewaretype}.txt "firmwaretype=\"${firmewaretype}\""  "$(getConfig LFS_CI_HWSWID_DB_TABLE -t hw_platform:${hw_platform})"
        done
    done

    datafrommysql HwSwId_CPRIMON.txt 'basebandfpga="CPRIMON"'     "$MYSQL_TABLE_FSMR3"
    datafrommysql HwSwId_CPRIIF.txt  'basebandfpga="CPRIIF"'      "$MYSQL_TABLE_FSMR3"
    datafrommysql HwSwId_D4P.txt     'basebandfpga="D4P"'         "$MYSQL_TABLE_FSMR3"

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
    local WORKDIR=$(getConfig LFS_CI_HWSWID_WORKDIR)

    export databaseName=hwswid_database
    mustHaveDatabaseCredentials

    local TABLENAME="$1"
    local QUERY="$2"
    local CURRENT_MYSQL_TABLE="$3"

    info creating "$TABLENAME" using MYSQL query "$QUERY" in "$WORKDIR" '(MYSQL '$MYSQL_USER@$MYSQL_HOST table $TABLENAME')'
    info +++ ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw_sw_id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY" >"$TABLENAME".tmp
    ### dems18x0: 2015-09-22: execute before mysql command is not working !
    ${mysql_cli} -B -r -s -e 'SELECT DISTINCT `hw_sw_id` FROM '"$CURRENT_MYSQL_TABLE"' WHERE '"$QUERY" >"$TABLENAME".tmp

    cat "$TABLENAME".tmp | grep -v '^$' | grep -v 'NULL' | sort -u >"$TABLENAME"
    rm "$TABLENAME.tmp"

    cat $TABLENAME
    rawDebug $TABLENAME
}


## @fn     removeminor
#  @brief
#  @param   <none>
#  @return  <none>
removeminor() {
    local HWSWID="$1"

    sed -e 's/..$/01/' "$HWSWID" | sort -u  >"$HWSWID".new
    mv "$HWSWID".new "$HWSWID"
}


## @fn     HwSwIdToSubVersion
#  @brief
#  @param   <none>
#  @return  <none>
HwSwIdToSubVersion() {
    local DEFSFILE="$PROJECT_SUBTASKS/HwSwId/HwSwIdToSubVersion.def"
    local WORKDIR=/lvol2/production_jenkins/tmp/HwSwId
    local SVNWORKDIR=/lvol2/production_jenkins/tmp/HwSwId.SVN
    local AUTOCOMMIT=true

    while read URL
    do
        case "$URL"
        in \#* | "" ) continue
        esac

        TMPFILE=$(mktemp /tmp/HwSwId1.XXXXXXXX)
        svn list "$URL" >"$TMPFILE"

        HWSWIDFOUND=false
        DIFF=false
        echo checking "$URL"
        while read FILENAME
        do
            case "$FILENAME"
            in HwSwId_*.txt)
                HWSWIDFOUND=true
            esac
        done <"$TMPFILE"
        rm -f "$TMPFILE"
        $HWSWIDFOUND || error "$URL: no HwSwId...txt file found"
        rm -rf "$SVNWORKDIR"
        svn co "$URL" "$SVNWORKDIR"
        DIFF=false
        for FILE in "$SVNWORKDIR"/HwSwId*.txt
        do
            FILENAME=$(basename "$FILE")
            [ -f "$WORKDIR"/"$FILENAME" ] || error "$FILENAME" not in current workdir "$WORKDIR"
            diff "$WORKDIR"/"$FILENAME" "$FILE" || {
                DIFF=true
                cp -f "$WORKDIR"/"$FILENAME" "$FILE"
            }
        done
        if $DIFF
        then
            if $AUTOCOMMIT
            then
                cd "$SVNWORKDIR"
                svn info | grep "^URL:"
                svn diff
                # DISABLED ###svn commit -m "BTSPS-1657 IN psulm: update HwSwId NOJCHK"
                info TODO: svn commit -m "BTSPS-1657 IN psulm: update HwSwId NOJCHK"
                cd -
            else
                info
                info Please goto "$SVNWORKDIR" and commit changes
                info Then rerun $0
                info '    cd '"$SVNWORKDIR"
                info '    svn commit -m "BTSPS-1657 IN psulm: update HwSwId NOJCHK"'
                info '    cd -'
                info '    '"$PROJECT_SUBTASK_REEXECPREFIX"
                exit 1
            fi
        fi

    done <"$DEFSFILE"
    rm -rf "$SVNWORKDIR"
}
