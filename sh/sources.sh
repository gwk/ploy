#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

ls \
src/*.swift \
src/forms/*.swift \
qk/src/Core/ArithmeticType.swift \
qk/src/Core/backport.swift \
qk/src/Core/check.swift \
qk/src/Core/DefaultInitializable.swift \
qk/src/Core/DuplicateErrors.swift \
qk/src/Core/Error.swift \
qk/src/Core/File.swift \
qk/src/Core/fs.swift \
qk/src/Core/Random.swift \
qk/src/Core/SetDict.swift \
qk/src/Core/SetRef.swift \
qk/src/Core/Array.swift \
qk/src/Core/Character.swift \
qk/src/Core/CollectionType.swift \
qk/src/Core/Dictionary.swift \
qk/src/Core/Int.swift \
qk/src/Core/Optional.swift \
qk/src/Core/OutputStreamType.swift \
qk/src/Core/Process.swift \
qk/src/Core/SequenceType.swift \
qk/src/Core/Set.swift \
qk/src/Core/String.swift \
