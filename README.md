# moonlit

[中文](README.zh-CN.md)

moonlit is a type checker (kernel) for Lean 4 written in
[MoonBit++](https://github.com/GreckF/mbtpp), MoonBit with dependent types,
proofs and algebraic effects. It reads environments exported by
[lean4export](https://github.com/leanprover/lean4export) (NDJSON format 3.1)
and checks every declaration. The algorithms follow
[lean4lean](https://github.com/digama0/lean4lean)
([paper](https://arxiv.org/abs/2403.14064)).

## Status

- **The kernel works but is not yet verified.** Type inference, weak head
  normalization, definitional equality, inductive types (mutual and nested,
  with generated recursors checked against the exported ones), quotients and
  Nat/String literals are implemented. See the test report below.
- **The formal verification has barely started.** The plan is for the
  checker to return certificates (judgments as `Prop` families, with whnf,
  defeq and inference returning their results together with proofs) and to
  prove the decision procedures correct. So far there is only a partial
  soundness proof of the universe level decision procedure, in
  [`wip/level_proof.mbtpp`](wip/level_proof.mbtpp), not yet used by the
  kernel. The kernel itself contains no proofs yet.
- Unsafe inductive types are rejected (not supported). Partial definitions
  are checked like safe ones; safe declarations may not use unsafe or partial
  ones.

## Requirements

- `moonpp` built from the main branch of
  [GreckF/mbtpp](https://github.com/GreckF/mbtpp) at commit `1b59716` or later
  (release 0.6.2 lacks fixes moonlit needs);
- `moon` (tested with 0.1.20261028);
- Node.js 18 or later (tested with 20.16).

## Build and run

```bash
bash scripts/build.sh                    # compiles to bin/moonlit.mjs
node bin/run.mjs path/to/export.ndjson
```

The output is one line: `ACCEPT <n>` when every declaration checks (`<n>`
counts the added declarations), or `REJECT line <k>: <reason>` at the first
declaration that does not.

`bin/run.mjs` runs the kernel in a worker thread with a large stack: the
checker is deeply recursive, and the main thread's stack is small (1 MB on
Windows). Setting `MOONLIT_STATS=1` also prints counters (arena nodes, whnf
calls and cache hits, β/δ/ι reductions).

## Tests

The tests are those of the lean kernel arena; they are not included in this
repository. Put them in `tests/arena/` (`tests/arena/good/…`,
`tests/arena/bad/…`), then:

```bash
bash scripts/run_tests.sh [filter] [timeout-seconds]   # summary
bash scripts/arena_report.sh [timeout-seconds]         # one line per test
```

A test in `good/` passes when it is accepted, one in `bad/` when it is
rejected.

## Layout

| File | Contents |
| --- | --- |
| `src/main/json.mbtpp` | NDJSON parser |
| `src/main/name.mbtpp`, `level.mbtpp` | names; universe levels and a complete decision procedure for `≤` |
| `src/main/expr.mbtpp` | expressions, hash-consed in an arena (equality and caches are O(1)); substitution; region-based collection |
| `src/main/env.mbtpp` | declarations, environment, local context |
| `src/main/tc.mbtpp` | type inference, whnf, definitional equality, literals, quotient and recursor reduction |
| `src/main/inductive.mbtpp` | inductive types: checks, recursor generation, nested inductives |
| `src/main/decl.mbtpp` | checking declarations; quotients |
| `src/main/loader.mbtpp` | replaying an export file |
| `wip/level_proof.mbtpp` | work in progress: verified level decision procedure |

## Test report

Run on 2026-11-02 with the code in this commit; raw results, one line per
test, in [`reports/arena-2026-11-02.tsv`](reports/arena-2026-11-02.tsv).

Setup: Windows 11, Node.js 20.16, `moonpp` at `1b59716`, moon 0.1.20261028,
the JS build (`bash scripts/build.sh`), one test at a time, a **60 s time
limit per test**.

**Result: 203 of 207 tests pass.** Every test in `bad/` is rejected and no
test in `good/` is rejected. The 4 failures are tests in `good/perf` that do
not finish within 60 s.

| Category | Passed | Total | Time (s) |
| --- | --- | --- | --- |
| `bad/bugs` | 26 | 26 | 8.3 |
| `bad/other` | 5 | 5 | 1.4 |
| `bad/perf` | 2 | 2 | 0.8 |
| `bad/tutorial` | 47 | 47 | 14.0 |
| `good/corner-cases` | 1 | 1 | 0.3 |
| `good/init-prelude.ndjson` | 1 | 1 | 1.6 |
| `good/other` | 5 | 5 | 1.4 |
| `good/perf` | 22 | 26 | 322.9 |
| `good/tutorial` | 94 | 94 | 29.0 |
| **Total** | **203** | **207** | 379.7 |

Failures (all timeouts at 60 s):

| Test | Separate run with a longer limit |
| --- | --- |
| `good/perf/app-lam` | not finished within 400 s |
| `good/perf/magma-list-deep-n21` | accepted after 282 s |
| `good/perf/magma-list-deep-n36` | not tried beyond 60 s |
| `good/perf/magma-list-pair-n21` | not finished within 400 s |

The slowest tests that pass: `magma-list-pair-n7` 40.9 s, `grind-ring-5`
13.7 s, `beta-ladder` 13.1 s, `let-ladder` 6.3 s; every other test takes
under 2 s (`init-prelude`: 1.6 s).

The `magma-list` tests check a `decide` proof that enumerates a magma
equation in 5 variables over `Fin n`; `app-lam` has not been profiled yet.
Making these fast is the next piece of work.

