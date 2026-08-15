# Benchmark Baselines

## Environments

| Field        | amd64                                     | arm64                        |
| ------------ | ----------------------------------------- | ---------------------------- |
| Date         | 2026-08-15                                | 2026-08-15                   |
| Go version   | go1.26.1 linux/amd64                      | go1.26.5 darwin/arm64        |
| CPU          | 12th Gen Intel Core i7-1255U (Alder Lake) | Apple M5                     |
| SIMD backend | AVX2                                      | NEON                         |
| OS           | Linux 6.8.0-137-generic                   | macOS 26.6.1                 |

> **Note:** Both are laptop CPUs with dynamic clocking; the Intel part is
> additionally P-core/E-core hybrid. Best-of-3 values are reported.

## Reading these numbers

Two traps in this suite:

- The `*Ref` and `*Generic` benchmarks call a copy of the scalar loop defined
  in the test files. Those get **inlined into the benchmark loop**, while the
  dispatched entry points cannot be. They are therefore *not* a fair
  SIMD-vs-Go baseline and will flatter the scalar side. To compare backends
  honestly, run the same benchmark twice, once with `-tags purego`.
- `-benchtime` defaults are too short for the small sizes. Use an explicit
  `-benchtime` and `-count=3`.

## Block operations, ns/op (best of 3)

| Operation           |   n | amd64 AVX2 | arm64 NEON |
| ------------------- | --: | ---------: | ---------: |
| AddBlock            |  4K |      663.1 |      647.6 |
| AddBlock            | 64K |    21840.0 |    13614.0 |
| MulBlock            |  4K |      695.7 |      592.1 |
| MulBlock            | 64K |    21527.0 |    13714.0 |
| ScaleBlock          |  4K |      995.7 |      581.7 |
| ScaleBlock          | 64K |    20434.0 |     9568.0 |
| AddMulBlock         |  4K |      758.5 |      757.7 |
| AddMulBlock         | 64K |    20388.0 |    14975.0 |
| MulAddBlock         |  4K |      933.3 |      942.0 |
| MulAddBlock         | 64K |    40628.0 |    20697.0 |
| Magnitude           |  4K |     2723.0 |     2203.0 |
| Power               |  4K |      826.8 |     1118.0 |

## AXPY: AddScaledBlockInPlace

`dst[i] += src[i] * scale`, against the two-pass idiom it replaces
(`ScaleBlock` into a temporary, then `AddBlockInPlace` — both SIMD, so the
difference is purely the extra pass over memory and the scratch buffer).

|   n | amd64 two-pass | amd64 axpy |    x | arm64 two-pass | arm64 axpy |    x |
| --: | -------------: | ---------: | ---: | -------------: | ---------: | ---: |
| 256 |           60.5 |       31.0 | 1.95 |           76.5 |       27.7 | 2.76 |
|  1K |          164.0 |       99.7 | 1.65 |          310.2 |      100.3 | 3.09 |
|  4K |         1162.0 |      513.2 | 2.26 |         1059.0 |      388.8 | 2.72 |
| 16K |         4790.0 |     2272.0 | 2.11 |         4825.0 |     2676.0 | 1.80 |
| 64K |        31709.0 |    11707.0 | 2.71 |        20104.0 |    10686.0 | 1.88 |

## Reductions — known arm64 gap

The reduction kernels are the one place where NEON does clearly worse than
AVX2 in absolute terms, on a CPU that beats the Intel part on every
elementwise operation:

| Operation  |    n | amd64 AVX2 | arm64 NEON | arm64 / amd64 |
| ---------- | ---: | ---------: | ---------: | ------------: |
| DotProduct | 4096 |      570.8 |     1870.0 |         3.28x |
| Sum        | 4096 |      622.8 |     1260.0 |         2.02x |
| MaxAbs     |   4K |      962.1 |     2263.0 |         2.35x |
| MaxAbs     |  64K |    17546.0 |    35979.0 |         2.05x |

They are still faster than the generic Go path on the same machine (measured
with `-tags purego`, NEON is 1.2x-2.2x ahead), so this is headroom, not a
regression. The cause is that `dotproduct.s` and `sum.s` accumulate with
*scalar* `FMADDD` into two accumulators, whereas the AVX2 versions use
4-wide vector accumulators.

The fix for DotProduct and Sum is to accumulate in `V` registers with
`VFMLA` (the only vector floating-point arithmetic mnemonic the Go assembler
accepts on arm64 — a sum can use it against a vector of ones), with four
accumulators to cover the FMA latency, then reduce horizontally at the end.
MaxAbs cannot be done this way: the Go assembler exposes no vector `FMAX` or
`FABS`, so it would need more scalar accumulators instead.

## How to Reproduce

```bash
go test -bench=. -benchtime=200ms -benchmem -count=3
go test -bench=. -benchtime=200ms -count=3 -tags purego   # scalar baseline
```

## How to Update

1. Run benchmarks on the target machine.
2. Replace the tables above with new results.
3. Update the environment section (date, Go version, CPU, OS).
