#!/bin/bash

set -o errexit

export PERL5LIB=${LFS_CI_ROOT}/lib/perl
prove -v -c --shuffle --state save --timer -r test/perl/

