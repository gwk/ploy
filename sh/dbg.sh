#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

make build

mainPath="$1"; shift || mainPath="_repro.ploy"
stem=${mainPath%.ploy}
outPath="_build/$stem.js"
outDir=$(dirname "$outPath")

mkdir -p "$outDir"
PATH=/usr/bin lldb --file _build/debug/ploy -- build lib -mapper ./gen-source-map -main "$mainPath" -o "$outPath"
