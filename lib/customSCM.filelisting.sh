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

    export subTaskName=$(getSubTaskNameFromJobName)
    local directoryNameToSynchronize=$(getConfig ADMIN_sync_share_local_directoryName)

    # read the revision state file
    # format:
    # projectName
    # buildNumber
    { read oldDirectoryNameToSynchronize ; 
      read oldChecksum ; } < "${REVISION_STATE_FILE}"

    trace "old revision state data are ${oldDirectoryNameToSynchronize} / ${oldChecksum}"

    # comparing to new state
    if [[ "${directoryNameToSynchronize}" != "${oldDirectoryNameToSynchronize}" ]] ; then
        info "directory name changed, trigger build"
        exit 0
    fi

    local checksum=$(ls -lat ${directoryNameToSynchronize} | md5sum | cut -d" " -f 1)

    if [[ "${checksum}" != "${oldChecksum}" ]] ; then
        info "checksum has changed, trigger build"
        exit 0
    fi

    info "no change in ${directoryNameToSynchronize} / ${checksum}"
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

    export subTaskName=$(getSubTaskNameFromJobName)
    local directoryNameToSynchronize=$(getConfig ADMIN_sync_share_local_directoryName)
    local oldFileListing=$(createTempFile)
    local newFileListing=$(createTempFile)
    local checksum=$(ls -lat ${directoryNameToSynchronize} | md5sum | cut -d" " -f 1)

    tail -n +3 ${OLD_REVISION_STATE_FILE} > ${oldFileListing}
    find ${directoryNameToSynchronize} -maxdepth 1 -printf "%p %C@\n" -maxdepth 1 | sort > ${newFileListing}

    echo "${directoryNameToSynchronize}" >  ${REVISION_STATE_FILE}
    echo "${checksum}"                   >> ${REVISION_STATE_FILE}
    cat ${newFileListing}                >> ${REVISION_STATE_FILE}

    local logEntries=$(createTempFile)
    for path in $(diff ${oldFileListing} ${newFileListing} | grep '>' | cut -d" " -f 2 | grep -v "^${directoryNameToSynchronize}$")
    do
        printf '<path kind="" action="M">%s</path>' ${path} >> ${logEntries}
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
            <msg>updates</msg>
            </logentry>
            </log>' \
    "$(date +%s)"                        \
    "${USER}"                            \
    "$(date +%Y-%m-%dT%H:%M:%S.000000Z)" \
    "$(cat ${logEntries})"               > ${CHANGELOG}

    # Fix empty changelogs:
    if [ ! -s "${CHANGELOG}" ] ; then
        echo -n "<log/>" >"${CHANGELOG}"
    fi

    return
}

## @fn      actionCalculate()
#  @brief   action ...
#  @details «full description»
#  @param   <none>
#  @return  <none>
actionCalculate() {
    return 
}

