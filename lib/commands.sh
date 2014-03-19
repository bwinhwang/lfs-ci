#!/bin/bash

execute() {
    local command=$@
    local output=$(createTempFile)

    trace "execute command: \"${command}\""

    ${command} >${output} 2>&1

    exitCode=$?
    trace "exit code of \"${command}\" was ${exitCode}"

    rawDebug ${output}

    if [[ ${exitCode} -gt 0 ]] ; then
        rawOutput ${output}
        error "error occoured in \"${command}\""
        exit ${exitCode}
    fi

    return
}

showAllEnvironmentVariables() {
    local key=""
    # workaround for screen / TERMCAP
    keys=$( env | grep = | grep -v '^!' | awk -F= '{ if ( ! $0 ~ /\\\\$/ ) print $1; }' )
    for key in ${keys}; do
        trace "environment variable: ${key} = \"${!key}\"" 
    done
}

cleanupEnvironmentVariables() {
    local key=""
    # workaround for screen / TERMCAP
    keys=$( env | grep = | grep -v '^!' | awk -F= '{ if ( ! $0 ~ /\\\\$/ ) print $1; }' )

    for key in ${keys}; do
        case ${key} in
            PATH|HOME|USER|HOSTNAME) : ;;
            LFS_CI_PATH) : ;;
            LFS_CI_SHARE_MIRROR) : ;;
            WORKSPACE) : ;;
            SVN_REVISION) : ;;
            *) 
                trace "unsetting environment variable \"${key}\" with value \"${!key}\"" 
                unset ${key} 
            ;;
        esac
    done
}

