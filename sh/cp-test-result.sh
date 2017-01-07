#!/bin/sh

set -e

path="$1"; shift
stem="${path%.*}"
ext="${path#*.}"

set -x
cp _build/"$stem"/"$ext" "$stem"."$ext"
