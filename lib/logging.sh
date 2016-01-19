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
        CI_LOGGING_LOGFILENAME_COMPLETE=${LFS_CI_ROOT}/log/${datePath}/ci.${dateString}.${hostName}.${userName}.${jobName}.${prefix}${counter}.complete.log
        mkdir -p ${LFS_CI_ROOT}/log/${datePath}/ 

        while [[ -e ${CI_LOGGING_LOGFILENAME}    ||
                 -e ${CI_LOGGING_LOGFILENAME}.gz ]] ; do
            counter=$(( counter + 1 ))
            CI_LOGGING_LOGFILENAME=${LFS_CI_ROOT}/log/${datePath}/ci.${dateString}.${hostName}.${userName}.${jobName}.${counter}.log
            CI_LOGGING_LOGFILENAME_COMPLETE=${LFS_CI_ROOT}/log/${datePath}/ci.${dateString}.${hostName}.${userName}.${jobName}.${counter}.complete.log
        done

        export CI_LOGGING_LOGFILENAME
        export CI_LOGGING_LOGFILENAME_COMPLETE
        export CI_LOGGING_DURATION_START_DATE=$(date +%s.%N)

        echo 1>&2 "logfile is ${CI_LOGGING_LOGFILENAME}"

        # hardcoded variables here. We have no possibility to use settings here - before the logfile is running
        local url=
        case ${USER} in
            psulm)    url=http://ullinn11.emea.nsn-net.net/lfs/ci/log ;;
            lfscidev) url=https://lfs-sandbox.emea.nsn-net.net/logs ;;
            ca_lrcci) url=https://lfs-lrc-ci.int.net.nokia.com/logs ;;
        esac
        if [[ ${url} ]] ; then
            echo 1>&2 "short log    : ${url}/${datePath}/$(basename ${CI_LOGGING_LOGFILENAME})"
            echo 1>&2 "complete log : ${url}/${datePath}/$(basename ${CI_LOGGING_LOGFILENAME_COMPLETE}).gz"
        fi

        printf -- "------------------------------------------------------------------\n" >  ${CI_LOGGING_LOGFILENAME}
        printf -- "starting short logfile\n"                                             >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  script: $0\n"                                                       >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  jobName:  $jobName\n"                                               >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  hostname: $hostName\n"                                              >> ${CI_LOGGING_LOGFILENAME}
        printf -- "  username: $userName\n"                                              >> ${CI_LOGGING_LOGFILENAME}
        printf -- "------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}
        printf -- "-- Please note, all timestamps are in UTC                       --\n" >> ${CI_LOGGING_LOGFILENAME}
        printf -- "------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}
        printf -- "{{{\n"                                                                >> ${CI_LOGGING_LOGFILENAME}

        printf -- "------------------------------------------------------------------\n" >  ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "starting complete logfile\n"                                          >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "  script: $0\n"                                                       >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "  jobName:  $jobName\n"                                               >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "  hostname: $hostName\n"                                              >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "  username: $userName\n"                                              >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "-- Please note, all timestamps are in UTC                       --\n" >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "{{{\n"                                                                >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
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
        printf -- "ending short logfile\n"                                                >> ${CI_LOGGING_LOGFILENAME}
        printf -- "-------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME}

        printf -- "}}}\n"                                                                 >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "-------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "script: $0\n"                                                          >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "ending complete logfile\n"                                             >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
        printf -- "-------------------------------------------------------------------\n" >> ${CI_LOGGING_LOGFILENAME_COMPLETE}

        gzip -f ${CI_LOGGING_LOGFILENAME_COMPLETE}
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
    _stackTrace
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
    local logLine=

    startLogfile
    
    # current defined log formats:
    # console output:
    # PREFIX DATE_SHORT SPACE DURATION SPACE TYPE SPACE MESSAGE
    # short log file:
    # PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE -- CALLER
    # complete log file:
    # PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER

    # create and write log message into complete logfile
    local logLineFile=$(_loggingLine "${logType}"                                                                                  \
                                     "${LFS_CI_LOGGING_CONFIG-"PREFIX DATE SPACE DURATION SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER"}" \
                                     "${logMessage}")
    echo -e 1>&2 "${logLineFile}" >> ${CI_LOGGING_LOGFILENAME_COMPLETE}

    # this is a blacklisting. 
    # filter out the messages which should not be in the shorten log file
    shouldWriteLogMessageToFile ${logType} || return 0

    # create and write log message into shorten logfile
    logLineFile=$(_loggingLine "${logType}"                                                                                  \
                               "${LFS_CI_LOGGING_CONFIG-"PREFIX DATE_SHORT SPACE TYPE SPACE MESSAGE SPACE -- SPACE CALLER"}" \
                               "${logMessage}")
    # Deactivate short log
    echo -e 1>&2 "${logLineFile}" >> ${CI_LOGGING_LOGFILENAME}

    # don't show TRACE and DEBUG message in screen, 
    # For screen, we create a different type of message.
    case "${logType}" in
        TRACE) return ;;
        DEBUG) return ;;
    esac

    # create and show the log message to the console
    local logLine=$(_loggingLine "${logType}"                                                                                      \
                                 "${LFS_CI_LOGGING_CONFIG-"PREFIX DATE SPACE DURATION SPACE TYPE MESSAGE"}" \
                                 "${logMessage}")
    # We are redirecting log messages to stderr. 
    # We don't want to have log messages in a local foobar=$(getFunction) call.
    echo -e 1>&2 "${logLine}" 
    return 0
}

## @fn      shouldWriteLogMessageToFile()
#  @brief   checks, if a log message should be written into the logfile or not.
#  @param   {logType}    type of the log message (INFO, WARNING, ERROR, DEBUG, TRACE)
#  @return  1 if message should be logged, 0 otherwise
shouldWriteLogMessageToFile() {
    local logType=$1
    local sourceFile=${BASH_SOURCE[3]/${LFS_CI_ROOT}\//}
    local sourceFunction=${FUNCNAME[3]}

    # grep returns with 0 if grep finds the string.
    # => if is true and returns 1
    if grep --silent -e "^${logType}:${sourceFile}:${sourceFunction}$" ${LFS_CI_ROOT}/etc/logging.cfg
    then
        return 1
    fi
    return 0
}

## @fn      _loggingLine()
#  @brief   format a log line
#  @param   {logType}    type of the message
#  @param   {logConfig}  config of a log message line
#  @param   {logMessage} a text message
#  @return  log line
_loggingLine() {
    local logType=$1
    local logConfig=$2
    local logMessage=$3
    local logLine=

    local prefix=${CI_LOGGING_PREFIX-${CI_LOGGING_PREFIX_HASH["$logType"]}}

    for template in ${logConfig} ; do

        case "${template}" in 
            LINE)       logLine=$(printf "%s%s" "${logLine}" "-----------------------------------------------------------------") ;;
            SPACE)      logLine=$(printf "%s "  "${logLine}" ) ;;
            NEWLINE)    logLine=$(printf "%s%s" "${logLine}" "\n" ) ;;
            TAB)        logLine=$(printf "%s\t" "${logLine}" ) ;;
            PREFIX)     logLine=$(printf "%s%s" "${logLine}" "${prefix}" ) ;;
            DATE_SHORT) logLine=$(printf "%s%s" "${logLine}" "$(date "+%Y-%m-%d %H:%M:%S")" ) ;;
            DATE)       logLine=$(printf "%s%s" "${logLine}" "$(date "+%Y-%m-%d %H:%M:%S.%N %Z")" ) ;;
            TYPE)       logLine=$(printf "%s%-10s" "${logLine}" "[${logType}]" );;
            DURATION) 
                        local cur=$(date +%s.%N)
                        local old=${CI_LOGGING_DURATION_START_DATE}
                        local dur=$(echo ${cur} - ${old} | bc)
                        logLine=$(printf "%s[%9.3f]" "${logLine}" ${dur})
            ;;
            NONE)       : ;;
            MESSAGE)    logLine=$(printf "%s%s" "${logLine}" "${logMessage}") ;;
            CALLER)     local sourceFile=${BASH_SOURCE[3]/${LFS_CI_ROOT}\//}
                        logLine=$(printf "%s%s:%s#%s"        \
                                         "${logLine}"        \
                                         "${sourceFile}"     \
                                         "${FUNCNAME[3]}"    \
                                         "${BASH_LINENO[2]}" )
            ;;
            STACKTRACE) _stackTrace ;;
            *)          logLine=$(printf "%s%s" "${logLine}" "${template}") ;;
        esac

    done

    echo "${logLine}"
    return
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
    cat ${fileToLog} >> ${CI_LOGGING_LOGFILENAME_COMPLETE}
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
