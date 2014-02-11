#!/bin/bash

set -o errexit

source lib/ci_logging.sh

for file in test/*.sh ; do
    
    info "executing unit test ${file}"
    ${file} || exit 1

done

exit 0

