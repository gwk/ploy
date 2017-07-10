#!/bin/sh

set -e

path="$1"; shift
stem="${path%.*}"
name=$(basename "$path")
ext="${path#*.}"

set -x
cp "_build/$stem/$name" "$path"
