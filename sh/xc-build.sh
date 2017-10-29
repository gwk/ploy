#!/usr/bin/env bash

set -e
error() { echo "$@" 1>&2; exit 1; }
warn() { echo "$@" 1>&2; }
source ~/.bashrc || warn "xc-build.sh: note: ~/.bashrc does not exist; attempting to compile with default PATH: $PATH"
craft-swift
