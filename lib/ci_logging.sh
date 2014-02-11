#!/bin/bash

isInteractiveShell() {
    fd=0
    if [[ -t "${fd}" ]] ; then
        echo 1
    else
        echo 0
    fi
}

## @fn      debug( message )
#  @brief   shows a debug message
#  @param   {message}    a text message
#  @return  <none>
debug() {
    message "DEBUG" "$@"
}

## @fn      info( message )
#  @brief   shows a info message
#  @param   {message}    a text message
#  @return  <none>
info() {
    message "INFO" "$@"
}

## @fn      error( message )
#  @brief   shows a error message
#  @param   {message}    a text message
#  @return  <none>
error() {
    message "ERROR" "$@"
}

## @fn      warning( message )
#  @brief   shows a warning message
#  @param   {message}  a text message
#  @return  <none>
warning() {
    message "WARNING" "$@"
}

## @fn      message( logType, logMessage )
#  @brief   shows a warning message
#  @detail  
#  @param   {logType}    type of the message
#  @param   {logMessage} a text message
#  @return  <none>
message() {
    local logType=$1
    local logMessage=$2

    if [[ ${CI_LOGGING_ENABLE_COLORS} && isInteractiveShell ]] ; then
        YELLOW="\033[33m"
        WHITE="\033[37m"
        RED="\033[31m"
        GREEN="\033[32m"
        CYAN="\033[36m"
    fi

    local config=${CI_LOGGING_CONFIG-"DATE SPACE TYPE SPACE MESSAGE NEWLINE"}
    local prefix=${CI_LOGGING_PREFIX-${CI_LOGGING_PREFIX_HASH["$logType"]}}
    local color=${CI_LOGGING_COLOR-${CI_LOGGING_COLOR_HASH["$logType"]}}

    printf -v date "%-20s" "`date`"

    if [[ "${CI_LOGGING_ENABLE_COLORS}" && "${color}" ]] ; then
        echo -en ${!color}
    fi

    for template in ${config}
    do
        case "${template}" in 
            LINE)    printf -- "-----------------------------------------------------------------" ;;
            SPACE)   printf " "                    ;;
            NEWLINE) printf "\n"                   ;;
            TAB)     printf "\t"                   ;;
            PREFIX)  printf "%s"   "${prefix}"     ;;
            DATE)    printf "%s"   "${date}"       ;;
            TYPE)    printf "%10s" "[${logType}]"  ;;
            NONE)    :                             ;;
            MESSAGE) 
                printf "%s" "${logMessage}" 
            ;;
            CALLER)
                printf "called from Method '%s' in File %s, Line %s"    \
                    "${FUNCNAME[2]}"                                    \
                    "${BASH_SOURCE[2]}"                                 \
                    "${BASH_LINENO[1]}"                               
            ;;
            STACKTRACE)
                _stackTrace
            ;;
        esac

    done

    if [[ "${CI_LOGGING_ENABLE_COLORS}" && "${color}" ]] ; then
        echo -en ${WHITE}
    fi

}
## @fn      _stackTrace()
#  @brief   shows the strack trace of this method call
#  @detail  based on http://blog.yjl.im/2012/01/printing-out-call-stack-in-bash.html
#           Copyright 2012 Yu-Jie Lin
#           MIT License
#           with some layout modification
#  @param   <none>
#  @return  <none>
_stackTrace() {
    local i=0
    local FRAMES=${#BASH_LINENO[@]}
    printf "Strack Trace: \n"
    # FRAMES-2 skips main, the last one in arrays
    for ((i=FRAMES-2; i>=0; i--)); do
        # Grab the source code of the line
        code=$(sed -n "${BASH_LINENO[i]}{s/^//;p}" "${BASH_SOURCE[i+1]}")
        printf "File %-30s Line %5d Method %-20s: %-100s\n"   \
                ${BASH_SOURCE[i+1]}              \
                ${BASH_LINENO[i]}                \
                ${FUNCNAME[i+1]}                 \
                "${code}"
    done 
}



