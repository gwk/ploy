#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

sources=$(sh/sources.sh)

mkdir -p _build

echo "swift.sh: destination path: $DST"
[[ -n "$DST" ]] || exit 1

for s in $0 $sources; do
  if [[ $s -nt "$DST" ]]; then
    echo "source changed: $s"
    stale="true"
  fi
done

[[ -z "$stale" ]] && echo "no change." && exit 0

swiftc \
-Onone \
-sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk \
-target x86_64-apple-macosx10.11 \
-module-name ploy \
-profile-coverage-mapping \
-profile-generate \
$sources \
"$@"
