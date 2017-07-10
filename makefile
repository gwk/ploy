# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

# $@: The file name of the target of the rule.
# $<: The name of the first prerequisite.
# $^: The names of all the prerequisites, with spaces between them.

.PHONY: _default all build clean cov gen test xcode

_default: test

all: clean gen build test

swift_build = sh/build.sh

build: src/lex.swift
	$(swift_build)

clean:
	rm -rf _build/*
	rm src/lex.swift

clean-ploy:
	rm -rf _build/debug/ploy*

cov:
	$(swift_build) -Xswiftc -profile-coverage-mapping -Xswiftc -profile-generate

gen: src/Lex.swift

src/lex.swift: ploy.legs
	legs $^ -output $@

test: build
	iotest -fail-fast

xcode:
	swift package generate-xcodeproj


_build:
	mkdir -p $@
