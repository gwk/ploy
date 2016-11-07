# © 2016 George King. Permission to use this file is granted in ploy/license.txt.

# $@: The file name of the target of the rule.
# $<: The name of the first prerequisite.
# $^: The names of all the prerequisites, with spaces between them.

.PHONY: default all build clean cov gen test

default: build

all: clean gen build test

swift_build = swift build --build-path _build

# src/Lex.swift
build:
	$(swift_build)
	@echo done.

clean:
	rm -rf _build/*

clean-ploy:
	rm -rf _build/debug/ploy*

cov:
	$(swift_build) -Xswiftc -profile-coverage-mapping -Xswiftc -profile-generate

gen: src/Lex.swift

src/Lex.swift: ploy.legs
	legs \
	-license 'Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.' \
	-output $@ \
	$^

test: build
	iotest test

_build:
	mkdir -p $@
