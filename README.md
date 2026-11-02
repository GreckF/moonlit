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

- **The kernel works.** Type inference, weak head normalization,
  definitional equality, inductive types (mutual and nested, with generated
  recursors checked against the exported ones), quotients and Nat/String
  literals are implemented. See the test report below.
- **Part of it carries proofs, which are not a formal verification.** The
  universe level operations the kernel uses are proved correct against a
  semantics of levels (see [About the proofs](#about-the-proofs)). The rest
  of the kernel has no proofs yet.
- Unsafe inductive types are rejected (not supported). Partial definitions
  are checked like safe ones; safe declarations may not use unsafe or partial
  ones.

## About the proofs

> **These proofs are not valid proofs, and moonlit is not formally verified.**
> They are checked by MoonBit++, whose logic is inconsistent by design
> (`Type : Type`, and neither termination nor strict positivity is checked):
> in it every proposition, including false ones, has a proof. A proof that
> MoonBit++ accepts therefore does not establish anything by itself. We write
> the proofs as if the logic were consistent (all recursion structural, no
> use of `Type : Type`), but nothing enforces this. Read them as an extra
> layer of assurance on top of testing, not as formal verification.

What is proved:

In [`src/main/level_proof.mbtpp`](src/main/level_proof.mbtpp), about universe
levels:

- the semantics: `ev(l, rho)` is the value of a level under an assignment
  `rho` of natural numbers to its parameters; `LevelLE(a, b)` says
  `ev(a, rho) <= ev(b, rho)` for every `rho`;
- `vleq(a, b)` returns a proof of `LevelLE(a, b)` or fails: every universe
  comparison of the kernel (`level_leq`, `level_equiv`) goes through it;
  only soundness is proved, not completeness;
- `never_zero` / `always_zero` (Lean's syntactic tests, used for
  projections from propositions and for elimination levels) return proofs
  that the level is positive / zero under every assignment;
- `mk_max` / `mk_imax` (the simplifications used when inferring the sort of
  a Π-type) return a level with the same value as `max a b` / `imax a b`;
- the substitution lemma for `Level::instantiate`, and as a consequence that
  substituting levels for parameters preserves `<=`.

In [`src/main/nat_proof.mbtpp`](src/main/nat_proof.mbtpp), about the Nat
literal extension (the kernel computes `Nat.add` etc. on literals with the
MoonBit++ Prelude's operations): those operations are equal to the
definitions of Lean's core library for `Nat.add`, `Nat.sub`, `Nat.mul`,
`Nat.pow`, `Nat.beq` and `Nat.ble`. `Nat.div`, `Nat.mod`, `Nat.gcd` and the
bitwise operations are not covered.

The proofs are erased when compiling, so they cost nothing at run time. They
rely on the axioms of the MoonBit++ Prelude for the primitive equalities
(`String::deq`, `Int::deq`).

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
| `src/main/name.mbtpp`, `level.mbtpp` | names; universe levels |
| `src/main/level_proof.mbtpp` | the semantics of levels; the decision procedure for `≤` and the other level operations, with proofs |
| `src/main/nat_proof.mbtpp` | Lean's definitions of the accelerated Nat operations, proved equal to the ones the kernel uses |
| `src/main/expr.mbtpp` | expressions, hash-consed in an arena (equality and caches are O(1)); substitution; region-based collection |
| `src/main/env.mbtpp` | declarations, environment, local context |
| `src/main/tc.mbtpp` | type inference, whnf, definitional equality, literals, quotient and recursor reduction |
| `src/main/inductive.mbtpp` | inductive types: checks, recursor generation, nested inductives |
| `src/main/decl.mbtpp` | checking declarations; quotients |
| `src/main/loader.mbtpp` | replaying an export file |

## Test report

Run on 2026-11-03 with the code in this commit; raw results, one line per
test, in [`reports/arena-2026-11-03.tsv`](reports/arena-2026-11-03.tsv).

Setup: Windows 11, Node.js 20.16, `moonpp` 0.6.3, moon 0.1.20261028,
the JS build (`bash scripts/build.sh`), one test at a time, a **60 s time
limit per test**.

**Result: 203 of 207 tests pass.** Every test in `bad/` is rejected and no
test in `good/` is rejected. The 4 failures are tests in `good/perf` that do
not finish within 60 s.

| Category | Passed | Total | Time (s) |
| --- | --- | --- | --- |
| `bad/bugs` | 26 | 26 | 10.0 |
| `bad/other` | 5 | 5 | 1.7 |
| `bad/perf` | 2 | 2 | 0.9 |
| `bad/tutorial` | 47 | 47 | 12.0 |
| `good/corner-cases` | 1 | 1 | 0.3 |
| `good/init-prelude.ndjson` | 1 | 1 | 1.5 |
| `good/other` | 5 | 5 | 1.3 |
| `good/perf` | 22 | 26 | 336.3 |
| `good/tutorial` | 94 | 94 | 43.6 |
| **Total** | **203** | **207** | 407.6 |

Failures (all timeouts at 60 s):

| Test | Separate run with a longer limit |
| --- | --- |
| `good/perf/app-lam` | not finished within 400 s |
| `good/perf/magma-list-deep-n21` | accepted after 282 s |
| `good/perf/magma-list-deep-n36` | not tried beyond 60 s |
| `good/perf/magma-list-pair-n21` | not finished within 400 s |

The slowest tests that pass: `magma-list-pair-n7` 53.0 s, `beta-ladder`
14.7 s, `grind-ring-5` 11.4 s, `let-ladder` 6.0 s; every other test takes
under 2 s (`init-prelude`: 1.5 s).

The `magma-list` tests check a `decide` proof that enumerates a magma
equation in 5 variables over `Fin n`; `app-lam` has not been profiled yet.
Making these fast is the next piece of work.

