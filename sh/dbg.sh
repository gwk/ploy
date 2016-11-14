#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

make build

mainPath="$1"; shift
stem=${mainPath%.ploy}
outPath="_build/_sh/$stem.js"
outDir=$(dirname "$outPath")

mkdir -p "$outDir"
lldb --file _build/debug/ploy -- lib/*.ploy -main "$mainPath" -o "$outPath"
