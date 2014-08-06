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
    # syntax is <share>_to_<site>
    export shareType=$(cut -d_ -f 1 <<< ${subTaskName})
    export siteName=$(cut -d_ -f 3 <<< ${subTaskName})
    local directoryNameToSynchronize=$(getConfig ADMIN_sync_share_local_directoryName)
    local findDepth=$(getConfig ADMIN_sync_share_check_depth)
    unset shareType siteName

    # remove this
    if [[ -z ${findDepth} ]] ; then
        findDepth=1
    fi
    # read the revision state file
    # format:
    # projectName
    # buildNumber
    { read oldDirectoryNameToSynchronize ; 
      read oldChecksum ; } < "${REVISION_STATE_FILE}"

    info "old revision state data are ${oldDirectoryNameToSynchronize} / ${oldChecksum}"

    # comparing to new state
    if [[ "${directoryNameToSynchronize}" != "${oldDirectoryNameToSynchronize}" ]] ; then
        info "directory name changed, trigger build"
        exit 0
    fi

    local checksum=$(find ${directoryNameToSynchronize} -mindepth ${findDepth} -maxdepth ${findDepth} -printf "%C@ %p\n" | sort | md5sum | cut -d" " -f 1)

    info "new revision state data are ${directoryNameToSynchronize} / ${checksum}"

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
    # syntax is <share>_to_<site>
    export shareType=$(cut -d_ -f 1 <<< ${subTaskName})
    export siteName=$(cut -d_ -f 3 <<< ${subTaskName})
    local directoryNameToSynchronize=$(getConfig ADMIN_sync_share_local_directoryName)
    local findDepth=$(getConfig ADMIN_sync_share_check_depth)
    unset shareType siteName
    # remove this
    if [[ -z ${findDepth} ]] ; then
        findDepth=1
    fi

    local oldFileListing=$(createTempFile)
    local newFileListing=$(createTempFile)

    info "create filelist from ${directoryNameToSynchronize} with depth = ${findDepth}"
    tail -n +3 ${OLD_REVISION_STATE_FILE} > ${oldFileListing}
    find ${directoryNameToSynchronize} -mindepth ${findDepth} -maxdepth ${findDepth} -printf "%C@ %p\n" | sort > ${newFileListing}
    local checksum=$(md5sum ${newFileListing} | cut -d" " -f 1 )

    echo "${directoryNameToSynchronize}" >  ${REVISION_STATE_FILE}
    echo "${checksum}"                   >> ${REVISION_STATE_FILE}
    cat ${newFileListing}                >> ${REVISION_STATE_FILE}

    diff -rub ${oldFileListing} ${newFileListing}

    local logEntries=$(createTempFile)
    local fileListString=
    for path in $(diff ${oldFileListing} ${newFileListing} | grep '>' | cut -d" " -f 3 | grep -v "^${directoryNameToSynchronize}$")
    do
        info "path ${path} has changed"
        if [[ ${path} =~ deleted ]] ; then
            debug "skip ${path}"
        fi
        printf "<path kind=\"\" action=\"M\">%s</path>\n" ${path} >> ${logEntries}
        fileListString="${fileListString} ${path}"
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
    "$(cat ${logEntries})"               \
    "${fileListString}"                  \
                                        > ${CHANGELOG}

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

