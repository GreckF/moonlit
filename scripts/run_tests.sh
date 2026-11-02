#!/usr/bin/env bash
# Run moonlit on the lean-kernel-arena tests: good/ must be accepted, bad/ rejected.
# usage: scripts/run_tests.sh [filter-substring] [timeout-seconds]
cd "$(dirname "$0")/.."
filter="${1:-}"
tmo="${2:-120}"
pass=0; fail=0
fails=()
for f in $(find tests/arena -name '*.ndjson' | sort); do
  case "$f" in *"$filter"*) ;; *) continue;; esac
  out=$(timeout "$tmo" node "${MOONLIT_RUN:-bin/run.mjs}" "$f" 2>&1 | grep -m1 -E "^(ACCEPT|REJECT|ERROR)")
  case "$f" in
    *"/good/"*) want=ACCEPT;;
    *) want=REJECT;;
  esac
  got="${out%% *}"
  if [ "$got" = "$want" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    fails+=("$f: $out")
  fi
done
for x in "${fails[@]}"; do echo "FAIL $x"; done
echo "passed $pass, failed $fail"
