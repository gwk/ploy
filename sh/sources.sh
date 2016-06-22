#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

ls \
src/*.swift \
qk/src/Core/ArithmeticFloat.swift \
qk/src/Core/ArithmeticProtocol.swift \
qk/src/Core/Array.swift \
qk/src/Core/Chain.swift \
qk/src/Core/Character.swift \
qk/src/Core/check.swift \
qk/src/Core/Collection.swift \
qk/src/Core/DefaultInitializable.swift \
qk/src/Core/Dictionary.swift \
qk/src/Core/DictOfSet.swift \
qk/src/Core/DuplicateErrors.swift \
qk/src/Core/Error.swift \
qk/src/Core/File.swift \
qk/src/Core/fs.swift \
qk/src/Core/Int.swift \
qk/src/Core/Optional.swift \
qk/src/Core/OutputStream.swift \
qk/src/Core/Process.swift \
qk/src/Core/Random.swift \
qk/src/Core/Ref.swift \
qk/src/Core/Sequence.swift \
qk/src/Core/Set.swift \
qk/src/Core/String.swift \
