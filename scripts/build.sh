#!/usr/bin/env bash
# Compile moonlit to JavaScript: bin/moonlit.mjs
set -e
cd "$(dirname "$0")/.."
out=$(moonpp build 2>&1) || { echo "$out"; exit 1; }
(cd mbtpp_out/main && moon build --target js --release >/dev/null)
cp mbtpp_out/main/_build/js/release/build/main/main.js bin/moonlit.mjs
echo "built bin/moonlit.mjs"
