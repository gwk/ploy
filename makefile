# © 2016 George King. Permission to use this file is granted in ploy/license.txt.

# $@: The file name of the target of the rule.
# $<: The name of the first prerequisite.
# $^: The names of all the prerequisites, with spaces between them. 

.PHONY: default all clean cov test

default: _build/ploy

all: clean test

clean:
	rm -rf .build/*
	rm -rf _build/*

cov:
	swift build -Xswiftc -profile-coverage-mapping -Xswiftc -profile-generate

test: _build/ploy
	iotest test

_build:
	mkdir -p $@

_build/ploy: _build
	@# creates .build/debug/ploy.
	swift build
	@# using a symlink does not work (do not understand why), but hardlink does.
	ln -f .build/debug/ploy $@
