#!/bin/bash

debug() {
    message "debug" "$@"
}

info() {
    message "info" "$@"
}

error() {
    message "error" "$@"
}

warning() {
    message "warning" "$@"
}

message() {
    local level=$1
    local message=$2

    printf -v date "%20s" "`date`"

    printf "%s%10s %s\n", \
           "${date-}"        \
           "[${level}]",     \
           "${message}"

}

