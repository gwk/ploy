#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
set -o pipefail

swift_plumage=$(which swift-plumage || echo cat) # optional.
swift build --build-path=_build "$@" 2>&1 | "$swift_plumage" | less
