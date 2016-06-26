#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

profs=$(find _build/test -name *.profraw -newer _build/ploy)

xcrun llvm-profdata merge -o _build/ploy.profdata $profs
xcrun llvm-cov show _build/ploy -instr-profile=_build/ploy.profdata $(ls src/*.swift)
