#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

sources=$(ls \
src/*.swift \
src/forms/*.swift \
qk/src/core/ArithmeticType.swift \
qk/src/core/check.swift \
qk/src/core/File.swift \
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
)

mkdir -p _bld

for s in $sources; do
  if [[ $s -nt _bld/ploy ]]; then
    echo "source changed: $s"
    stale="true"
  fi
done

[[ -z "$stale" ]] && exit 0

swiftc \
-Onone \
-sdk /Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk \
-target x86_64-apple-macosx10.10 \
$sources \
-o _bld/ploy \

