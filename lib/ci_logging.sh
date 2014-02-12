#!/bin/bash

startLogfile() {

    if [[ ! -w ${CI_LOGGING_LOGFILENAME} ]] ; then
        export CI_LOGGING_LOGFILENAME=logfile
        printf -- "------------------------------------------------------------------\n" >  ${CI_LOGGING_LOGFILENAME}
        printf -- "starting logfile\n"                                                   >> ${CI_LOGGING_LOGFILENAME}
        printf -- "------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}
    fi
}

stopLogfile() {

    if [[ -w ${CI_LOGGING_LOGFILENAME} ]] ; then
        printf -- "-------------------------------------------------------------------\n" >  ${CI_LOGGING_LOGFILENAME}
        printf -- "ending logfile\n"                                                      >> ${CI_LOGGING_LOGFILENAME}
        printf -- "-------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}
    fi
    
    unset CI_LOGGING_LOGFILENAME
}

## @fn      trace( message )
#  @brief   shows a trace message
#  @param   {message}    a text message
#  @return  <none>
trace() {
    message "TRACE" "$@"
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

    if [[ ${CI_LOGGING_ENABLE_COLORS} ]] ; then
        YELLOW="\033[33m"
        WHITE="\033[37m"
        RED="\033[31m"
        GREEN="\033[32m"
        CYAN="\033[36m"
    fi

    local color=${CI_LOGGING_COLOR-${CI_LOGGING_COLOR_HASH["$logType"]}}


    if [[ "${CI_LOGGING_ENABLE_COLORS}" && "${color}" ]] ; then
        echo -en ${!color}
    fi

    startLogfile

    logLine=$(_loggingLine ${logType} "${logMessage}")
    echo -e "${logLine}"
    echo -e "${logLine}" >> logfile

    if [[ "${CI_LOGGING_ENABLE_COLORS}" && "${color}" ]] ; then
        echo -en ${WHITE}
    fi
}

## @fn      _loggingLine( logType, logMessage )
#  @brief   format a log line
#  @param   {logType}    type of the message
#  @param   {logMessage} a text message
#  @return  <none>
_loggingLine() {
    local logType=$1
    local logMessage=$2

    local config=${CI_LOGGING_CONFIG-"DATE SPACE TYPE SPACE MESSAGE NEWLINE"}
    local prefix=${CI_LOGGING_PREFIX-${CI_LOGGING_PREFIX_HASH["$logType"]}}
    local dateFormat=${CI_LOGGING_DATEFORMAT-"+%s"}

    printf -v date "%-20s" "$(date ${dateFormat})"

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

logCommand() {
    local command=$1
    local output=$(${command})

    debug "logging command ${command}"

    CI_LOGGING_CONFIG="PREFIX SPACE MESSAGE"
    CI_LOGGING_PREFIX=">"

    while read A
    do
        debug "${A}"
    done <<<"${output}"

    unset CI_LOGGING_CONFIG
    unset CI_LOGGING_CONFIG

}


