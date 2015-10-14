#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

ls \
src/*.swift \
src/forms/*.swift \
qk/src/core/ArithmeticType.swift \
qk/src/core/check.swift \
qk/src/core/Error.swift \
qk/src/core/File.swift \
qk/src/core/fs.swift \
qk/src/std/Array.swift \
qk/src/std/Character.swift \
qk/src/std/CollectionType.swift \
qk/src/std/Dictionary.swift \
qk/src/std/Int.swift \
qk/src/std/Optional.swift \
qk/src/std/OutputStreamType.swift \
qk/src/std/Process.swift \
qk/src/std/SequenceType.swift \
qk/src/std/String.swift \
