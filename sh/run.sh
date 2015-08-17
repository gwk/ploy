#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

mainPath="$1"; shift
base=${mainPath%.ploy}
outPath="_bld/$base"
outDir=$(dirname "$outPath")

sh/build.sh
mkdir -p "$outDir"
_bld/ploy lib/*.ploy -main "$mainPath" -o "$outPath"
"$outPath" "$@"
