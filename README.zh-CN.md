# moonlit

[English](README.md)

moonlit 是用 [MoonBit++](https://github.com/GreckF/mbtpp)（带依赖类型、证明和代数效应的
MoonBit）写的 Lean 4 类型检查器（内核）。它读取
[lean4export](https://github.com/leanprover/lean4export) 导出的环境（NDJSON，格式 3.1），
逐条检查其中的声明。算法照
[lean4lean](https://github.com/digama0/lean4lean)（[论文](https://arxiv.org/abs/2403.14064)）实现。

## 现状

- **内核能用，但还没有经过验证。** 已实现类型推断、弱头规约、定义等价、归纳类型（互递归与嵌套，
  生成的递归子与导出文件中的逐一比对）、商类型以及 Nat/String 字面量。测试结果见下面的报告。
- **形式化验证才刚开始。** 计划让检查器返回证书：判断写成 `Prop` 族，whnf、定义等价和类型推断
  返回结果的同时给出证明；并证明各判定过程正确。目前只有宇宙层级判定的部分可靠性证明，
  在 [`wip/level_proof.mbtpp`](wip/level_proof.mbtpp)，还没有接入内核。内核本身还没有任何证明。
- 不支持 unsafe 归纳类型（直接拒绝）。partial 定义按 safe 定义检查；safe 声明不能使用 unsafe 或
  partial 声明。

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
| `src/main/name.mbtpp`、`level.mbtpp` | 名字；宇宙层级，以及 `≤` 的完备判定 |
| `src/main/expr.mbtpp` | 表达式：在 arena 中 hash-consing（相等与缓存都是 O(1)）；代换；按区域回收 |
| `src/main/env.mbtpp` | 声明、环境、局部上下文 |
| `src/main/tc.mbtpp` | 类型推断、whnf、定义等价、字面量、商类型与递归子的规约 |
| `src/main/inductive.mbtpp` | 归纳类型：检查、生成递归子、嵌套归纳类型 |
| `src/main/decl.mbtpp` | 声明的检查；商类型 |
| `src/main/loader.mbtpp` | 回放导出文件 |
| `wip/level_proof.mbtpp` | 进行中：经过验证的层级判定 |

## 测试报告

2026-11-02 用本次提交的代码测得。逐个测试的原始结果在
[`reports/arena-2026-11-02.tsv`](reports/arena-2026-11-02.tsv)。

环境：Windows 11，Node.js 20.16，`moonpp` `1b59716`，moon 0.1.20261028，JS 构建
（`bash scripts/build.sh`），逐个运行，**每个测试限时 60 秒**。

**结果：207 个测试通过 203 个。** `bad/` 中的测试全部被拒绝，`good/` 中没有测试被拒绝。
4 个失败都是 `good/perf` 中 60 秒内没有跑完的测试。

| 类别 | 通过 | 总数 | 耗时（秒） |
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
| **合计** | **203** | **207** | 379.7 |

失败的测试（都是 60 秒超时）：

| 测试 | 单独以更长时限运行的结果 |
| --- | --- |
| `good/perf/app-lam` | 400 秒内没有跑完 |
| `good/perf/magma-list-deep-n21` | 282 秒后接受 |
| `good/perf/magma-list-deep-n36` | 没有测试超过 60 秒的情况 |
| `good/perf/magma-list-pair-n21` | 400 秒内没有跑完 |

通过的测试中最慢的：`magma-list-pair-n7` 40.9 秒，`grind-ring-5` 13.7 秒，`beta-ladder`
13.1 秒，`let-ladder` 6.3 秒；其余都在 2 秒以内（`init-prelude` 1.6 秒）。

`magma-list` 系列检查的是一个 `decide` 证明：在 `Fin n` 上穷举一个 5 变量的 magma 等式；
`app-lam` 还没有剖析。让这几个测试变快是接下来的工作。

