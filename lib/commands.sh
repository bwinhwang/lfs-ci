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
    for key in `perl -e 'print map { "$_\n" } sort keys %ENV'` ; do
        trace "environment variable: ${key} = \"${!key}\"" 
    done
}

cleanupEnvironmentVariables() {
    local key=""
    for key in `perl -e 'print map { "$_\n" } sort keys %ENV'` ; do
        case ${key} in
            PATH|HOME|USER|HOSTNAME) : ;;
            CI_PATH) : ;;
            WORKSPACE) : ;;
            SVN_REVISION) : ;;
            *) 
                trace "unsetting environment variable \"${key}\" with value \"${!key}\"" 
                unset ${key} 
            ;;
        esac
    done
}

