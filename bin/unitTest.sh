#!/bin/bash

set -o exitError

for file in test/*.sh ; do
    
    debug "executing unit test ${file}"
    ${file} || exit 1

done

exit 0

