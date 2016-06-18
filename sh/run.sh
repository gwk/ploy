#!/bin/sh
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

mainPath="$1"; shift
base=${mainPath%.ploy}
outPath="_build/$base"
outDir=$(dirname "$outPath")

sh/build.sh
mkdir -p "$outDir"
_build/ploy lib/*.ploy -main "$mainPath" -o "$outPath"
"$outPath" "$@"

# TODO: move the profile dump.
#prof_cwd_path = 'default.profraw' # llvm name is fixed; always outputs to cwd.
#prof_path = exe_path + '.profraw'
