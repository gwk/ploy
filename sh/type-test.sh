#!/usr/bin/env bash
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e

PROJECT="$(dirname $0)/.."

make build
set -x
$PROJECT/_build/debug/ploy test-types "$@"
