#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

make .build/debug/ploy

mainPath="$1"; shift
stem=${mainPath%.ploy}
outPath="_build/_run/$stem.out" # the '_run' subdir distinguishes these products from test.
outDir=$(dirname "$outPath")

mkdir -p "$outDir"
.build/debug/ploy lib/*.ploy -main "$mainPath" -o "$outPath"
"$outPath" "$@"

# TODO: move the profile dump.
#prof_cwd_path = 'default.profraw' # llvm name is fixed; always outputs to cwd.
#prof_path = exe_path + '.profraw'
