# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

# $@: The file name of the target of the rule.
# $<: The name of the first prerequisite.
# $^: The names of all the prerequisites, with spaces between them.
# $*: The match for a `%` pattern rule.

.PHONY: _default all build clean cov docs gen test xcode

_default: test-fast

all: clean gen build test

build: src/lex.swift
	craft-swift

clean:
	rm -rf _build/*

clean-lex:
	rm -f src/lex.swift

clean-ploy:
	rm -rf _build/debug/ploy*

docs:
	craft-docs

cov:
	craft-swift -Xswiftc -profile-coverage-mapping -Xswiftc -profile-generate

gen: src/lex.swift

install-vscode:
	craft-vscode-ext -name ploy -src vscode-ext

run:
	sh/run.sh

src/lex.swift: ploy.legs
	legs $^ -output $@

test-fast: build
	iotest -fail-fast

test: build
	iotest

test/%: build
	iotest $@

_build:
	mkdir -p $@
