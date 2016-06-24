#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

export TARGET=_build/ploy

sh/swift.sh \
-o "$TARGET"
