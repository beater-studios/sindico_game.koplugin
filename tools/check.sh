#!/bin/sh
# Every check that runs without KOReader. The CI runs tools/check.sh; the release runs tools/check.sh release.
set -eu
cd "$(dirname "$0")/.."
luajit tools/validate.lua
for spec in tests/*_spec.lua; do
    luajit "$spec"
done
luajit tools/simulate.lua 1000
sh tools/package.sh
