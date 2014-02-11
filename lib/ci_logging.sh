#!/bin/bash

## @fn      debug( message )
#  @brief   shows a debug message
#  @param   {message}    a text message
#  @return  <none>
debug() {
    message "debug" "$@"
}

## @fn      info( message )
#  @brief   shows a info message
#  @param   {message}    a text message
#  @return  <none>
info() {
    message "info" "$@"
}

## @fn      error( message )
#  @brief   shows a error message
#  @param   {message}    a text message
#  @return  <none>
error() {
    message "error" "$@"
}

## @fn      warning( message )
#  @brief   shows a warning message
#  @param   {message}  a text message
#  @return  <none>
warning() {
    message "warning" "$@"
}

## @fn      warning( message )
#  @brief   shows a warning message
#  @param   {type}    type of the message
#  @param   {message} a text message
#  @return  <none>
message() {
    local type=$1
    local message=$2

    local config=${3-"DATE SPACE TYPE SPACE MESSAGE NEWLINE"}

    printf -v date "%-20s" "`date`"

    for template in ${config}
    do
        case "${template}" in 
            SPACE)   printf " "  ;;
            NEWLINE) printf "\n" ;;
            TAB)     printf "\t" ;;
            DATE)
                printf "%s" "${date}"
            ;;
            TYPE)
                printf "%10s" "[${type}]"
            ;;
            MESSAGE)
                printf "%s" "${message}"
            ;;
            LINE)
                printf -- "-----------------------------------------------------------------"
            ;;
            CALLER)
                printf "called from Method '%s' in File %s, Line %s"    \
                    "${FUNCNAME[2]}"                                    \
                    "${BASH_SOURCE[2]}"                               \
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



