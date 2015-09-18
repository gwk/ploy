#!/bin/bash
# Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

set -e

function render {
  dst=gh-pages/$2
  echo "$1 -> $dst"
  mkdir -p $(dirname $dst)
  writeup/writeup.py $1 $dst
}

render readme.wu index.html

for path in $(find doc -name '*.wu'); do
  [[ $path =~ doc/_misc/* ]] && continue
  render $path ${path%.wu}.html
done
