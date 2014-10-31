#!/bin/bash

## @fn      actionCompare()
#  @brief   
#  @details INPUT: REVISION_STATE_FILE revision state file from the old build
#  @param   <none>
#  @return  1 if if a build is not required, 0 otherwise
actionCompare() {

    if [[ -z "${REVISION_STATE_FILE}" ]] ; then
        info "no old revision state file found"
        exit 0
    fi

    local fileCount=$(ls /build/home/SC_LFS/pkgpool/.manifest/*.done 2>/dev/null | wc -l)
    if [[ ${fileCount} -gt 0 ]] ; then
        info "not todo files found in pkgpool: count = ${fileCount}"
        exit 0
        
    fi

    info "no change"
    exit 1
}


## @fn      actionCheckout()
#  @brief   action which is called by custom scm jenkins plugin to create or update a workspace and create the changelog
#  @details the create workspace task is empty here. We just calculate the changelog
#  @param   <none>
#  @return  <none>
actionCheckout() {
    # create a new changelog file
    cat < /dev/null > "${CHANGELOG}"


    local logEntries=$(createTempFile)
    local fileListString=
    for fileList in $(ls /build/home/SC_LFS/pkgpool/.manifest/*.done 2>/dev/null ) ; do
        info "new fileList ${fileList} found, processing"

        for path in $(cat ${fileList}) ; do
            printf "<path kind=\"\" action=\"A\">%s</path>\n" ${path} >> ${logEntries}
        done                
        fileListString="${fileListString} ${fileList}"
        execute mv -f ${fileList} ${fileList}.syned
    done

    # create changelog:
    printf '<?xml version="1.0"?>
            <log>
            <logentry revsion="%d">
            <author>%s</author>
            <date>%s</date>
            <paths>
                %s
            </paths>
            <msg>update in %s</msg>
            </logentry>
            </log>' \
    "$(date +%s)"                        \
    "${USER}"                            \
    "$(date +%Y-%m-%dT%H:%M:%S.000000Z)" \
    "$(cat ${logEntries} | sort -u)"     \
    "${fileListString}"                  \
                                        > ${CHANGELOG}

    # Fix empty changelogs:
    if [ ! -s "${CHANGELOG}" ] ; then
        echo -n "<log/>" >"${CHANGELOG}"
    fi

    execute -n date > ${REVISION_STATE_FILE}

    return
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details 
#  @param   <none>
#  @return  <none>
actionCalculate() {
    return 
}

