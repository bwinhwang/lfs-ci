tests := $(foreach file,$(shell ls test/*.sh),$(dir $(file)).tested/$(notdir $(file)))

.PHONY: all test tags doc clean

all:
	echo nothing todo...

$(tests):
	@echo running test/$(@F)
	@export LFS_CI_ROOT=${PWD} ; \
	bash test/$(@F)
	@mkdir -p $(@D)
	@touch $@

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

