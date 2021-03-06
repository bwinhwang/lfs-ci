tests := $(foreach file,$(shell ls test/*.sh),$(dir $(file)).tested/$(notdir $(file)))
tests_single := $(shell ls test/*.sh)

.PHONY: all test tags doc clean $(tests_single)

all:
	echo nothing todo...

$(tests):
	@echo running test/$(@F)
	@export LFS_CI_ROOT=${PWD} ; \
	bash test/$(@F)
	@mkdir -p $(@D)
	@touch $@

$(tests_single):
	@echo running test/$(@F)
	@export LFS_CI_ROOT=${PWD} ; \
	bash test/$(@F)

test: clean $(tests)

retest: $(tests)

tags:
	@ctags lib/*.sh bin/*.sh test/common.sh

doc:
	@doxygen doc/Doxyfile
	@${MAKE} -C doc/latex

clean:
	@rm -rf test/.tested/

help:
	@echo "make targets are:"
	@echo "doc     -- generate doxygen documentation"
	@echo "clean   -- remove old test result files"
	@echo "test    -- run all unit tests"
	@echo "retest  -- run only failed and not ran unit tests"
	@echo "tags    -- create ctags file for vim"

