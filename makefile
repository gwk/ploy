# © 2016 George King. Permission to use this file is granted in ploy/license.txt.

# $@: The file name of the target of the rule.
# $<: The name of the first prerequisite.
# $^: The names of all the prerequisites, with spaces between them.

.PHONY: default all build clean cov test

default: build

all: clean build test

swift_build = swift build # --build-path _build

build:
	$(swift_build)

clean:
	rm -rf .build/*
	rm -rf _build/*

clean-ploy:
	rm -rf .build/debug/ploy*
cov:
	$(swift_build) -Xswiftc -profile-coverage-mapping -Xswiftc -profile-generate

test: build
	iotest test

_build:
	mkdir -p $@
