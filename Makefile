tests := $(shell ls test/*.sh)

.PHONY: all test tags doc $(tests)

all:
	echo nothing todo...

$(tests):
	export LFS_CI_ROOT=${PWD} ; \
	bash $@

test: $(tests)

tags:
	ctags lib/*.sh bin/*.sh test/common.sh

doc:
	doxygen doc/Doxyfile
	${MAKE} -C doc/latex


