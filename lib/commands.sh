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
    execute printenv        
}

cleanupEnvironmentVariables() {
    local key=""

    # workaround for screen / TERMCAP
    unset TERM
    unset TERMCAP
    keys=`(set -o posix ; set ) | grep = | grep -v '^!' | awk -F= '{ if ( $0 ~ /\\\\$/ ) 
                                                                        a=1; 
                                                                     else 
                                                                        print $1; }' `
    for key in ${keys}; do
        case ${key} in
            BASH*) : ;; # can not unset 
            UID|EUID)  : ;;
            SHELLOPTS) : ;;
            PPID) : ;;
            PATH|HOME|USER|HOSTNAME) : ;;
            LFS_CI_ROOT) : ;;
            LFS_CI_SHARE_MIRROR) : ;;
            LFS_CI*) : ;;
            CI_LOGGING_LOGFILENAME) : ;;
            CI_*) : ;;
            WORKSPACE) : ;;
            SVN_REVISION) : ;;
            UPSTREAM*) : ;;
            BUILD_*) : ;;
            NODE_LABELS) : ;;
            *) 
                trace "unsetting environment variable \"${key}\" with value \"${!key}\"" 
                unset ${key} 
            ;;
        esac
    done
}

