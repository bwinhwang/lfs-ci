#!/bin/bash

source lib/ci_logging.sh

info "this is a test"

export CI_LOGGING_ENABLE_COLORS=1
declare -A CI_LOGGING_COLOR_HASH=( ["INFO"]="CYAN" \
                                   ["ERROR"]="RED" \
                                   ["WARNING"]="YELLOW" \
                                 )

echo $-
echo is interactive $(isInteractiveShell)
echo $PS1
info "this is a test"
warning "this is a test"
error "this is a test"
