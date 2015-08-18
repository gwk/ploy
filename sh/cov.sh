#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

profs=$(find _bld/test -name *.profraw -newer _bld/ploy)

xcrun llvm-profdata merge -o _bld/ploy.profdata $profs
xcrun llvm-cov show _bld/ploy -instr-profile=_bld/ploy.profdata $(sh/sources.sh | egrep '^src/')
