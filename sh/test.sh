#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e

cd $(dirname $0)/..

libs=$(ls lib/*.ploy)
tests="$@"

[[ -z "$tests" ]] && tests="test"

sh/run.sh test/0-basic/ret-0.ploy # pre-test to make sure that ploy works.
tools/test.py -compiler "_bld/ploy $libs" "$tests"

