#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

sources=$(sh/sources.sh)

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
-sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk \
-target x86_64-apple-macosx10.11 \
-profile-coverage-mapping \
-profile-generate \
$sources \
-o _bld/ploy \
