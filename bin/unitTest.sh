#!/bin/bash

export LFS_CI_ROOT=$PWD
export USER=psulm
export HOME=/path/to/home

make clean
make test -j 20
exit 0

