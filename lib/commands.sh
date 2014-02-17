#!/bin/bash

executeAndLogOutput() {

    logCommand

}
execute() {
    local command=$@

    trace "execute command: \"${command}\""

    ${command}

    exitCode=$?
    trace "exit code of \"${command}\" was ${exitCode}"

    if [[ ${exitCode} -gt 0 ]] ; then
        error "error occoured in \"${command}\""
        exit ${exitCode}
    fi

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
            CI_LIB_PATH) : ;;
            *) 
                trace "unsetting environment variable \"${key}\" with value \"${!key}\"" 
                unset ${key} 
            ;;
        esac
    done
}

