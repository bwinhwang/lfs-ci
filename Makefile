.PHONY: all test tags doc
all:
	echo nothing todo...

test:
	LFS_CI_ROOT=${PWD} bin/unitTest.sh

tags:
	ctags lib/*.sh bin/*.sh

doc:
	doxygen doc/Doxyfile
	${MAKE} -C doc/latex
