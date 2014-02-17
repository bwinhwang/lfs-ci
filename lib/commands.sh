#!/bin/bash

call() {
    local command=$@

    trace "calling command ${command}"

    ${command}

    exitCode=$?
    trace "exit code of ${command} was ${exitCode}"

    #exit ${exitCode}
    exit 1

}

cleanupEnvironmentVariables() {
    local key=""
    for key in `perl -e 'print map { "$_\n" } keys %ENV'` ; do
        case ${key} in
            PATH|HOME|USER|HOSTNAME) : ;;
            *) unset ${key} ;;
        esac
    done
}
