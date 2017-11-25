#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

make build

mainPath="$1"; shift || mainPath="test/_repro.ploy"
stem=${mainPath%.ploy}
outPath="_build/$stem.js"
outDir=$(dirname "$outPath")

mkdir -p "$outDir"
set -x
_build/debug/ploy lib -mapper ./gen-source-map -main "$mainPath" -o "$outPath"
"$outPath" "$@"

# TODO: move the profile dump.
#prof_cwd_path = 'default.profraw' # llvm name is fixed; always outputs to cwd.
#prof_path = exe_path + '.profraw'
