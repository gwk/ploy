#!/usr/bin/env bash
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e
cd $(dirname $0)/..

error() { echo $@ 1>&2; exit 1; }

mainPath="$1"; shift || mainPath="test/_repro.ploy"

if [[ ! -f "$mainPath" ]]; then
  if [[ -f "$mainPath"ploy ]]; then # tab completion often stops at the dot because of multiple ploy, err, iot extensions.
    mainPath="$mainPath"ploy
  else
    error "source file does not exist: $mainPath"
  fi
fi

stem=${mainPath%.ploy}
outPath="_build/$stem.js"
outDir=$(dirname "$outPath")

mkdir -p "$outDir"
make build
set -x
_build/debug/ploy build lib -mapper ./gen-source-map -main "$mainPath" -o "$outPath"
"$outPath" "$@"

# TODO: move the profile dump.
#prof_cwd_path = 'default.profraw' # llvm name is fixed; always outputs to cwd.
#prof_path = exe_path + '.profraw'
