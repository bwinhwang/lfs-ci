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

    printf -v date "%-20s" "`date`"

    printf "%s%10s %s\n"  \
           "${date-}"     \
           "[${type}]"    \
           "${message}"
}


