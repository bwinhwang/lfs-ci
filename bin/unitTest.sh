#!/bin/bash

set -o errexit

export LFS_CI_ROOT=$PWD
export USER=psulm
export HOME=/path/to/home

source ${LFS_CI_ROOT}/lib/logging.sh

for file in test/*.sh ; do
    info "executing unit test ${file}"
    ${file} 
done

exit 0

