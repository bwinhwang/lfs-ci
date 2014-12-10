.PHONY: all test tags
all:
	echo nothing todo...

test:
	LFS_CI_ROOT=${PWD} bin/unitTest.sh

tags:
	ctags lib/*.sh bin/*.sh
