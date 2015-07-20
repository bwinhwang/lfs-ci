#!/bin/bash
## @file    logging.sh
#  @brief   handling of output and logfiles
#  @details The scripting should avoid to use echo or printf to print out information to the console.
#           For this, we are using the following function:
#           - info
#           - error
#           - fatail
#           - warning
#           - debug
#           - trace
#           - rawDebug
# 
#           These function are doing this for you in the correct way. The message will be written to
#           the logfile and - dependend to the loglevel - to the console / jenkins output.
#           The logging functions are also adding the data to each message.
#
#           e.g.: 2015-01-26 06:34:33.693662137 UTC [    0.006] [ERROR]    this is an error.
#
#           The logfile will be written into the global log directory in the /ps/lfs/ci share.
#           In the exit handler, the logfile will be gzipped.
#           
#           You can also influence the format of the log file. See CI_LOGGING_CONFIG for details.
#

LFS_CI_SOURCE_logging='$Id$'

[[ -z ${LFS_CI_SOURCE_exit_handling} ]] && source ${LFS_CI_ROOT}/lib/exit_handling.sh

## @fn      startLogfile()
#  @brief   creates a new logfile and adds an header
#  @param   <none>
#  @return  <none>
startLogfile() {

    if [[ ! -w ${CI_LOGGING_LOGFILENAME} ]] ; then

        export TZ=Etc/UTC

        local jobName=${JOB_NAME:-unknownJobName}
        local dateString=$(date +%Y%m%d%H%M%S)
        local datePath=$(date +%Y/%m/%d)
        local hostName=$(hostname -s)
        local userName=${USER}

        local counter=0
        local prefix=

        if [[ ! -z ${LFS_CI_LOGGING_PREFIX} ]] ; then
            prefix=${LFS_CI_LOGGING_PREFIX}.
        fi

        CI_LOGGING_LOGFILENAME=${LFS_CI_ROOT}/log/${datePath}/ci.${dateString}.${hostName}.${userName}.${jobName}.${prefix}${counter}.log
        mkdir -p ${LFS_CI_ROOT}/log/${datePath}/ 

        while [[ -e ${CI_LOGGING_LOGFILENAME}    ||
                 -e ${CI_LOGGING_LOGFILENAME}.gz ]] ; do
            counter=$(( counter + 1 ))
            CI_LOGGING_LOGFILENAME=${LFS_CI_ROOT}/log/${datePath}/ci.${dateString}.${hostName}.${userName}.${jobName}.${counter}.log
        done

        export CI_LOGGING_LOGFILENAME
        export CI_LOGGING_DURATION_START_DATE=$(date +%s.%N)

        echo 1>&2 "logfile is ${CI_LOGGING_LOGFILENAME}"

        # hardcoded variables here. We have no possibility to use settings here - before the logfile is running
        local url=
        case ${USER} in
            psulm)    url=http://ullinn11.emea.nsn-net.net/lfs/ci/log/ ;;
            lfscidev) url=https://lfs-sandbox.emea.nsn-net.net/logs/ ;;
            ca_lrcci) url=https://lfs-lrc-ci.int.net.nokia.com/logs/ ;;
        esac
        if [[ ${url} ]] ; then
            echo 1>&2 "${url}/${datePath}/$(basename ${CI_LOGGING_LOGFILENAME})"
        fi

        printf -- "------------------------------------------------------------------\n" >  ${CI_LOGGING_LOGFILENAME}
        printf -- "starting logfile\n"                                                   >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  script: $0\n"                                                       >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  jobName:  $jobName\n"                                               >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  hostname: $hostName\n"                                              >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  username: $userName\n"                                              >> ${CI_LOGGING_LOGFILENAME}
        printf -- "------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}
        printf -- "-- Please note, all timestamps are in UTC                       --\n" >> ${CI_LOGGING_LOGFILENAME}
        printf -- "------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}
        printf -- "{{{\n"                                                                >> ${CI_LOGGING_LOGFILENAME}
    fi
}

## @fn      stopLogfile()
#  @brief   stop a logfile - if exists
#  @param   <none>
#  @return  <none>
stopLogfile() {

    if [[ -w ${CI_LOGGING_LOGFILENAME} ]] ; then
        printf -- "}}}\n"                                                                 >> ${CI_LOGGING_LOGFILENAME}
        printf -- "-------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}
        printf -- "script: $0\n"                                                          >> ${CI_LOGGING_LOGFILENAME}
        printf -- "ending logfile\n"                                                      >> ${CI_LOGGING_LOGFILENAME}
        printf -- "-------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}

        # disabled gzipping..
        # gzip ${CI_LOGGING_LOGFILENAME}
    fi
    
    unset CI_LOGGING_LOGFILENAME
}

## @fn      trace()
#  @brief   shows a trace message
#  @param   {message}    a text message
#  @return  <none>
trace() {
    message "TRACE" "$@"
}

## @fn      debug()
#  @brief   shows a debug message
#  @param   {message}    a text message
#  @return  <none>
debug() {
    message "DEBUG" "$@"
}

## @fn      info()
#  @brief   shows a info message
#  @param   {message}    a text message
#  @return  <none>
info() {
    message "INFO" "$@"
}

## @fn      error()
#  @brief   shows a error message
#  @param   {message}    a text message
#  @return  <none>
error() {
    message "ERROR" "$@"
}

## @fn      warning()
#  @brief   shows a warning message
#  @param   {message}  a text message
#  @return  <none>
warning() {
    message "WARNING" "$@"
}

## @fn      fatal()
#  @brief   shows a fatal message
#  @param   {message}  a fatal message
#  @return  <none>
fatal() {
    message "FATAL_ERROR" "$@"
    exit 1
}

## @fn      message()
#  @brief   shows a warning message
#  @detail  
#  @param   {logType}    type of the message
#  @param   {logMessage} a text message
#  @return  <none>
message() {
    local logType=$1
    shift
    local logMessage=$@

    if [[ ${CI_LOGGING_ENABLE_COLORS} ]] ; then
        YELLOW="\033[33m"
        WHITE="\033[37m"
        RED="\033[31m"
        GREEN="\033[32m"
        CYAN="\033[36m"
    fi

    local color=${CI_LOGGING_COLOR-${CI_LOGGING_COLOR_HASH["$logType"]}}


    if [[ "${CI_LOGGING_ENABLE_COLORS}" && "${color}" ]] ; then
        echo -en 1>&2 ${!color} 
    fi

    startLogfile

    logLine=$(_loggingLine ${logType} "${logMessage}")

    # ------------------------------------------------------------------------------------------
    # interal stuff
    # generate the logline
    local config=${CI_LOGGING_CONFIG-"PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE NEWLINE"}
    local prefix=${CI_LOGGING_PREFIX-${CI_LOGGING_PREFIX_HASH["$logType"]}}
    local dateFormat=${CI_LOGGING_DATEFORMAT-"+%Y-%m-%d %H:%M:%S.%N %Z"}

    for template in ${config}
    do
        case "${template}" in 
            LINE)    logLine=$(printf "%s%s" "${logLine}" "-----------------------------------------------------------------") ;;
            SPACE)   logLine=$(printf "%s "  "${logLine}" ) ;;
            NEWLINE) logLine=$(printf "%s\n" "${logLine}" ) ;;
            TAB)     logLine=$(printf "%s\t" "${logLine}" ) ;;
            PREFIX)  logLine=$(printf "%s%s" "${logLine}" "${prefix}" ) ;;
            DATE)    logLine=$(printf "%s%s" "${logLine}" "$(date "${dateFormat}")" ) ;;
            TYPE)    logLine=$(printf "%s%-10s" "${logLine}" "[${logType}]" );;
            DURATION) 
                     local cur=$(date +%s.%N)
                     local old=${CI_LOGGING_DURATION_START_DATE}
                     local dur=$(echo ${cur} - ${old} | bc)
                     logLine=$(printf "%s[%9.3f]" "${logLine}" ${dur})
            ;;
            NONE)    : ;;
            MESSAGE) 
                logLine=$(printf "%s%s" "${logLine}" "${logMessage}")
            ;;
            CALLER)
                logLine=$(printf "called from Method '%s' in File %s, Line %s" \
                    "${logLine}"                                               \
                    "${FUNCNAME[2]}"                                           \
                    "${BASH_SOURCE[2]}"                                        \
                    "${BASH_LINENO[1]}" )
            ;;
            STACKTRACE)
                _stackTrace
            ;;
        esac

    done
    # -------------------------------------------------------------------------------------------

    case "${logType}" in
        TRACE) : ;;
        DEBUG) : ;;
        *) echo -e 1>&2 "${logLine}" ;;
    esac

    echo -e 1>&2 "${logLine}" >> ${CI_LOGGING_LOGFILENAME}

    if [[ "${CI_LOGGING_ENABLE_COLORS}" && "${color}" ]] ; then
        echo -en 1>&2 ${WHITE}
    fi
}

## @fn      _loggingLine()
#  @brief   format a log line
#  @param   {logType}    type of the message
#  @param   {logMessage} a text message
#  @return  <none>
_loggingLine() {
    local logType=$1
    local logMessage=$2

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
    printf 1>&2 "Stack Trace: \n"
    # FRAMES-2 skips main, the last one in arrays
    for ((i=FRAMES-2; i>=0; i--)); do
        # Grab the source code of the line
        local code=$(sed -n "${BASH_LINENO[i]}{s/^\s*//;p}" "${BASH_SOURCE[i+1]}")
        local file=${BASH_SOURCE[i+1]}
        local fileString="$(printf "%s(%s:%s)" ${FUNCNAME[i+1]}           \
                                               ${file//${LFS_CI_ROOT}\//} \
                                               ${BASH_LINENO[i]}          )"
        printf 1>&2 "at %-30s\n\t%-100s\n" \
                "${fileString}"            \
                "${code}"
    done 
}

## @fn      rawDebug()
#  @brief   put the content of the file into the logfile
#  @param   {fileName}    name of the file
#  @param   <none>
#  @return  <none>
rawDebug() {
    local fileToLog=$1

    # file is empty
    if [[ ! -s ${fileToLog} ]] ; then
        trace "file ${fileToLog} is empty"
        return
    fi            

    trace "{{{ adding content of file ${fileToLog} to logfile"
    trace     "----------------------------------------------"
    cat ${fileToLog} >> ${CI_LOGGING_LOGFILENAME}
    trace "}}} ----------------------------------------------"

    return
}

## @fn      rawOutput()
#  @brief   put the content of the file on the console
#  @param   {fileName}    name of the file
#  @param   <none>
#  @return  <none>
rawOutput() {
    local fileToLog=$1

    # file is empty
    [[ ! -s ${fileToLog} ]] && return

    trace "{{{ content of file ${fileToLog}"
    trace "    ----------------------------------------------"
    cat ${fileToLog} 
    trace "}}} ----------------------------------------------"

    return
}
