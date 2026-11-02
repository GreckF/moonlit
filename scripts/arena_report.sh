#!/usr/bin/env bash
# Run every arena test and print one tab-separated line per test:
#   path  expected  got  seconds  message
# usage: scripts/arena_report.sh [timeout-seconds]
cd "$(dirname "$0")/.."
tmo="${1:-60}"
for f in $(find tests/arena -name '*.ndjson' | sort); do
  case "$f" in
    *"/good/"*) want=ACCEPT;;
    *) want=REJECT;;
  esac
  s=$(date +%s%N)
  out=$(timeout "$tmo" node "${MOONLIT_RUN:-bin/run.mjs}" "$f" 2>&1 | grep -m1 -E "^(ACCEPT|REJECT|ERROR)")
  e=$(date +%s%N)
  got="${out%% *}"
  [ -z "$got" ] && got=TIMEOUT
  printf '%s\t%s\t%s\t%.1f\t%s\n' "$f" "$want" "$got" "$(( (e - s) / 100000000 ))e-1" "${out#* }"
done
