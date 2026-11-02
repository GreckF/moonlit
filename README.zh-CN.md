# moonlit

[English](README.md)

moonlit 是用 [MoonBit++](https://github.com/GreckF/mbtpp)（带依赖类型、证明和代数效应的
MoonBit）写的 Lean 4 类型检查器（内核）。它读取
[lean4export](https://github.com/leanprover/lean4export) 导出的环境（NDJSON，格式 3.1），
逐条检查其中的声明。算法照
[lean4lean](https://github.com/digama0/lean4lean)（[论文](https://arxiv.org/abs/2403.14064)）实现。

## 现状

- **内核能用。** 已实现类型推断、弱头规约、定义等价、归纳类型（互递归与嵌套，生成的递归子与导出
  文件中的逐一比对）、商类型以及 Nat/String 字面量。测试结果见下面的报告。
- **一部分带有证明，但这不是形式化验证。** 内核用到的宇宙层级运算，相对于层级的语义证明了正确；
  弱头规约和定义等价返回证书（见[关于证明](#关于证明)）。类型推断和声明的检查还没有证明。
- 不支持 unsafe 归纳类型（直接拒绝）。partial 定义按 safe 定义检查；safe 声明不能使用 unsafe 或
  partial 声明。

## 关于证明

> **这些证明并不是有效的证明，moonlit 也没有经过形式化验证。** 证明由 MoonBit++ 检查，而
> MoonBit++ 的逻辑按设计就是不一致的（`Type : Type`，并且不检查终止性和严格正性）：在其中任何
> 命题，包括假命题，都有证明。所以 MoonBit++ 接受了一个证明，这件事本身并不能说明什么。我们按
> “逻辑是一致的”来写证明（递归都是结构递归，不利用 `Type : Type`），但没有任何机制保证这一点。
> 请把它们看作测试之外多加的一层保证，而不是形式化验证。

证明了的内容：

[`src/main/level_proof.mbtpp`](src/main/level_proof.mbtpp) 中，关于宇宙层级：

- 语义：`ev(l, rho)` 是层级在参数赋值 `rho`（参数到自然数）下的值；`LevelLE(a, b)` 表示对每个
  `rho` 都有 `ev(a, rho) <= ev(b, rho)`；
- `vleq(a, b)` 要么给出 `LevelLE(a, b)` 的证明，要么失败：内核的所有宇宙比较（`level_leq`、
  `level_equiv`）都经过它；只证明了可靠性，没有证明完备性；
- `never_zero` / `always_zero`（Lean 的语法判定，用于命题的投影和消去层级）给出层级在任意赋值下
  为正 / 为零的证明；
- `mk_max` / `mk_imax`（推断 Π 类型所在的宇宙时用的化简）返回的层级与 `max a b` / `imax a b`
  的值相同；
- `Level::instantiate` 的代换引理，以及由此推出的：用层级代换参数保持 `<=`。

[`src/main/nat_proof.mbtpp`](src/main/nat_proof.mbtpp) 中，关于 Nat 字面量扩展（内核用
MoonBit++ Prelude 的运算直接计算字面量上的 `Nat.add` 等）：这些运算与 Lean 核心库中
`Nat.add`、`Nat.sub`、`Nat.mul`、`Nat.pow`、`Nat.beq`、`Nat.ble` 的定义相等。`Nat.div`、
`Nat.mod`、`Nat.gcd` 和位运算没有覆盖。

证书，见 [`src/main/judgment.mbtpp`](src/main/judgment.mbtpp)（规则）和
[`src/main/defeq.mbtpp`](src/main/defeq.mbtpp)：

- `whnf` 返回结果 `r`，同时给出 `Red(k, e, r)` 的推导：`e` 经内核的规约步骤（β、ζ、δ、let 绑定的
  变量、投影、Nat 字面量、字符串字面量）规约到 `r`；
- `is_def_eq` 每次回答“相等”时，都给出按算法规则推出 `DefEq(k, t, s)` 的推导（同余、在新变量下比较
  binder、用已证明的层级等价比较 sort、η、结构体 η、证明无关、unit-like 类型、Nat 字面量）；union-find
  和其他缓存中存的也是带推导的结果。

证书说明答案能由这些规则推出；它不说明这些规则就是 Lean 类型论的规则，也不说明规则中用到的原语是
正确的。作为原语被信任的：arena 上的操作（`view`、`instantiate`、`mk_*`）、环境与局部上下文、展开
定义、取构造子应用的字段。目前作为单条规则被信任的：递归子与商类型的规约（`RRec`）、定义等价中用到
的类型推断（η、结构体 η、证明无关、unit-like 类型），以及垃圾回收保留在用的项（`RCopy`）。

证明在编译时被擦除，运行时没有开销（构造带证书的结果有一些分配开销）。原始类型的相等
（`String::deq`、`Int::deq`）和指针相等（`ptr_deq`）依赖 MoonBit++ Prelude 中的公理。

## 环境要求

- 用 [GreckF/mbtpp](https://github.com/GreckF/mbtpp) 主分支 `1b59716` 或更新的提交构建的
  `moonpp`（0.6.2 发布版缺少 moonlit 需要的修复）；
- `moon`（在 0.1.20261028 上测试）；
- Node.js 18 或以上（在 20.16 上测试）。

## 构建与运行

```bash
bash scripts/build.sh                    # 编译到 bin/moonlit.mjs
node bin/run.mjs path/to/export.ndjson
```

输出一行：所有声明都通过时是 `ACCEPT <n>`（`<n>` 是加入环境的声明数），否则是
`REJECT line <k>: <原因>`，`<k>` 是第一条不通过的声明所在的行号。

`bin/run.mjs` 在大栈的 worker 线程中运行内核：检查器递归很深，而主线程的栈很小（Windows 上
1 MB）。设置 `MOONLIT_STATS=1` 会额外输出计数器（arena 节点数、whnf 调用与缓存命中、β/δ/ι 规约
次数）。

## 测试

测试来自 lean kernel arena，本仓库不包含它们。把测试放在 `tests/arena/` 下
（`tests/arena/good/…`、`tests/arena/bad/…`），然后：

```bash
bash scripts/run_tests.sh [过滤字符串] [每个测试的时限秒数]   # 汇总
bash scripts/arena_report.sh [每个测试的时限秒数]             # 每个测试一行
```

`good/` 中的测试被接受、`bad/` 中的测试被拒绝，才算通过。

## 目录

| 文件 | 内容 |
| --- | --- |
| `src/main/json.mbtpp` | NDJSON 解析 |
| `src/main/name.mbtpp`、`level.mbtpp` | 名字；宇宙层级 |
| `src/main/level_proof.mbtpp` | 层级的语义；`≤` 的判定及其他层级运算，带证明 |
| `src/main/nat_proof.mbtpp` | Lean 对被加速的 Nat 运算的定义，证明与内核所用的运算相等 |
| `src/main/judgment.mbtpp` | 给内核的回答作证书的判断 `Red` 和 `DefEq` |
| `src/main/defeq.mbtpp` | 定义等价，带证书 |
| `src/main/expr.mbtpp` | 表达式：在 arena 中 hash-consing（相等与缓存都是 O(1)）；代换；按区域回收 |
| `src/main/env.mbtpp` | 声明、环境、局部上下文 |
| `src/main/tc.mbtpp` | 类型推断、whnf（带证书）、字面量、商类型与递归子的规约 |
| `src/main/inductive.mbtpp` | 归纳类型：检查、生成递归子、嵌套归纳类型 |
| `src/main/decl.mbtpp` | 声明的检查；商类型 |
| `src/main/loader.mbtpp` | 回放导出文件 |

## 测试报告

2026-11-03 用本次提交的代码测得。逐个测试的原始结果在
[`reports/arena-2026-11-03.tsv`](reports/arena-2026-11-03.tsv)。

环境：Windows 11，Node.js 20.16，`moonpp` 0.6.3，moon 0.1.20261028，JS 构建
（`bash scripts/build.sh`），逐个运行，**每个测试限时 60 秒**。

**结果：207 个测试通过 203 个。** `bad/` 中的测试全部被拒绝，`good/` 中没有测试被拒绝。
4 个失败都是 `good/perf` 中 60 秒内没有跑完的测试。

| 类别 | 通过 | 总数 | 耗时（秒） |
| --- | --- | --- | --- |
| `bad/bugs` | 26 | 26 | 8.8 |
| `bad/other` | 5 | 5 | 1.5 |
| `bad/perf` | 2 | 2 | 1.2 |
| `bad/tutorial` | 47 | 47 | 13.7 |
| `good/corner-cases` | 1 | 1 | 0.3 |
| `good/init-prelude.ndjson` | 1 | 1 | 1.5 |
| `good/other` | 5 | 5 | 1.5 |
| `good/perf` | 22 | 26 | 320.6 |
| `good/tutorial` | 94 | 94 | 27.5 |
| **合计** | **203** | **207** | 376.6 |

失败的测试（都是 60 秒超时）：

| 测试 | 单独以更长时限运行的结果 |
| --- | --- |
| `good/perf/app-lam` | 400 秒内没有跑完 |
| `good/perf/magma-list-deep-n21` | 282 秒后接受 |
| `good/perf/magma-list-deep-n36` | 没有测试超过 60 秒的情况 |
| `good/perf/magma-list-pair-n21` | 400 秒内没有跑完 |

通过的测试中最慢的：`magma-list-pair-n7` 42.5 秒，`beta-ladder` 12.9 秒，`grind-ring-5`
11.2 秒，`let-ladder` 5.6 秒；其余都在 2 秒以内（`init-prelude` 1.5 秒）。

`magma-list` 系列检查的是一个 `decide` 证明：在 `Fin n` 上穷举一个 5 变量的 magma 等式；
`app-lam` 还没有剖析。让这几个测试变快是接下来的工作。

