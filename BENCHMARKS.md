# Benchmark Baselines

## Environments

| Field        | amd64                                     | arm64                        |
| ------------ | ----------------------------------------- | ---------------------------- |
| Date         | 2026-08-15                                | 2026-08-15                   |
| Go version   | go1.26.1 linux/amd64                      | go1.26.5 darwin/arm64        |
| CPU          | 12th Gen Intel Core i7-1255U (Alder Lake) | Apple M5 (4 P-core + 6 E-core) |
| SIMD backend | AVX2                                      | NEON                         |
| OS           | Linux 6.8.0-137-generic                   | macOS 26.6.1                 |

> **Note:** Both are laptop CPUs with dynamic clocking; the Intel part is
> additionally P-core/E-core hybrid.

## Reading these numbers

Three traps in this suite. The third was learned the hard way while measuring
the arm64 rewrite below.

- The `*Ref` and `*Generic` benchmarks call a copy of the scalar loop defined
  in the test files. Those get **inlined into the benchmark loop**, while the
  dispatched entry points cannot be. They are therefore *not* a fair
  SIMD-vs-Go baseline and will flatter the scalar side. To compare backends
  honestly, run the same benchmark twice, once with `-tags purego`.
- `-benchtime` defaults are too short for the small sizes. Use an explicit
  `-benchtime` and `-count=3`.
- **Run-to-run variance on an unplugged laptop swamps anything under about
  1.3x.** The arm64 figures were partly taken on battery, and back-to-back runs
  of *identical, untouched* code moved by as much as 1.58x (`Power/1K` measured
  183 ns and then 290 ns from the same tree). Treat a lone sub-1.3x number as
  no result at all. Where a ratio below that appears below, it is because the
  same direction reproduced across several sizes, not because one run said so.

A cheap safeguard, used throughout the arm64 comparison: keep some **untouched
kernels in the same run as controls**. `AddScaledBlockInPlace`, `Magnitude` and
the `RotateDecay*` pair were not modified, and they land at 0.96x-1.00x. A
measured change in a kernel that *was* modified is only believable when the
controls sat still.

## arm64: the VFMLA rewrite

Before and after the NEON kernels became actual SIMD, same machine, same
settings (`-benchtime=300ms -count=3`, best of 3, ns/op). "before" is commit
`29d1c23`, where every kernel except `axpy.s` was a 2x-unrolled *scalar* loop.

| Operation           |     n | before |  after |    x |
| ------------------- | ----: | -----: | -----: | ---: |
| ScaleBlock          |    1K |    132 |     79 | 1.67 |
| ScaleBlock          |    4K |    501 |    296 | 1.69 |
| ScaleBlock          |   16K |   1961 |   1256 | 1.56 |
| ScaleBlockInPlace   |    4K |   1451 |   1234 | 1.18 |
| AddBlock            |    1K |    152 |     95 | 1.60 |
| AddBlock            |    4K |    579 |    378 | 1.53 |
| MulBlock            |    1K |    143 |    103 | 1.39 |
| MulBlock            |    4K |    535 |    423 | 1.26 |
| AddMulBlock         |    1K |    162 |     98 | 1.65 |
| AddMulBlock         |    4K |    624 |    382 | 1.63 |
| MulAddBlock         |    1K |    195 |    133 | 1.47 |
| MulAddBlock         |    4K |    765 |    517 | 1.48 |
| **Sum**             |  1024 |    247 |    118 | 2.09 |
| **Sum**             |  4096 |   1113 |    468 | 2.38 |
| **Sum**             | 16384 |   4586 |   1844 | 2.49 |
| **Sum**             | 65536 |  18482 |   7417 | 2.49 |
| **DotProduct**      |  1024 |    357 |    119 | 3.00 |
| **DotProduct**      |  4096 |   1675 |    464 | 3.61 |
| **DotProduct**      | 16384 |   7464 |   1889 | 3.95 |
| **DotProduct**      | 65536 |  28715 |   7624 | 3.77 |

The 64K rows of the elementwise kernels sit at 1.01x-1.04x: at that size the
loops are memory-bound and the extra lanes buy nothing. The reductions keep
winning there because they read one stream and write nothing.

### The reduction gap is closed, and reversed

The previous revision of this file recorded DotProduct at 4096 as 3.28x
*behind* the AVX2 kernel, on a CPU that won every elementwise comparison. With
four vector accumulators instead of two scalar ones, arm64 is now ahead:

| Operation  |    n | amd64 AVX2 | arm64 NEON (before) | arm64 NEON (after) |
| ---------- | ---: | ---------: | ------------------: | -----------------: |
| DotProduct | 4096 |      570.8 |                1870 |            **464** |
| Sum        | 4096 |      622.8 |                1260 |            **468** |

### Short inputs keep the scalar path

Vectorising made the reductions slower below roughly a hundred elements, where
the fixed prologue and horizontal fold cannot be amortised — Sum of 16 elements
measured 0.29x. Both kernels now branch to a two-accumulator scalar loop under
a threshold measured by forcing each path over a size sweep:

|          n |  16 |  32 |  48 |  64 |  96 | 128 | 192 | 256 | 512 |
| ---------- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| Sum scalar |   2 |   5 |   6 |   8 |  12 |  17 |  28 |  46 | 106 |
| Sum vector |   7 |   8 |  10 |  12 |  15 |  18 |  26 |  33 |  62 |
| Dot scalar |   3 |   5 |   7 |   9 |  15 |  23 |  40 |  63 | 134 |
| Dot vector |   7 |   8 |  10 |  12 |  16 |  19 |  26 |  33 |  62 |

They cross in different places — **128 for DotProduct, 192 for Sum** — because
Sum's scalar path issues half the loads per element and so is harder to beat.
With the split in place, `Sum` and `DotProduct` at n=16 and n=64 are back to
1.00x against the old kernels.

This matters beyond the microbenchmark: `algo-dsp/dsp/filter/fir` calls
`DotProduct` once per output sample and takes the vecmath path from 32 taps up,
so without the split a 32-tap FIR would have been handed a slower kernel.

### Kernels deliberately left scalar

`VFMLA`/`VFMLS` are the only vector floating-point arithmetic mnemonics the Go
arm64 assembler accepts, which is enough for any affine combination but not for
these:

- `maxabs.s` — no vector `FMAX` or `FABS`, and NEON has no 64-bit-lane integer
  max either, so the bit-pattern trick is unavailable.
- `magnitude.s`, `power.s` — no vector `FSQRT`.
- `dither.s` — serial by construction.

The float32 modal-oscillator ops (`RotateDecay*`) are a different case: they are
*not* blocked, since `VFMLA` does accept the `S4` arrangement for 4-lane float32
FMA. They simply have not been written yet.

## Block operations, ns/op — amd64 (unchanged)

No amd64 code changed in the rewrite above; these are for cross-architecture
reference.

| Operation           |   n | amd64 AVX2 |
| ------------------- | --: | ---------: |
| AddBlock            |  4K |      663.1 |
| AddBlock            | 64K |    21840.0 |
| MulBlock            |  4K |      695.7 |
| MulBlock            | 64K |    21527.0 |
| ScaleBlock          |  4K |      995.7 |
| ScaleBlock          | 64K |    20434.0 |
| AddMulBlock         |  4K |      758.5 |
| AddMulBlock         | 64K |    20388.0 |
| MulAddBlock         |  4K |      933.3 |
| MulAddBlock         | 64K |    40628.0 |
| Magnitude           |  4K |     2723.0 |
| Power               |  4K |      826.8 |

## AXPY: AddScaledBlockInPlace

`dst[i] += src[i] * scale`, against the two-pass idiom it replaces
(`ScaleBlock` into a temporary, then `AddBlockInPlace` — both SIMD, so the
difference is purely the extra pass over memory and the scratch buffer).

|   n | amd64 two-pass | amd64 axpy |    x | arm64 two-pass | arm64 axpy |    x |
| --: | -------------: | ---------: | ---: | -------------: | ---------: | ---: |
| 256 |           60.5 |       31.0 | 1.95 |           49.0 |       27.0 | 1.81 |
|  1K |          164.0 |       99.7 | 1.65 |          177.0 |       96.0 | 1.84 |
|  4K |         1162.0 |      513.2 | 2.26 |          661.0 |      368.0 | 1.80 |
| 16K |         4790.0 |     2272.0 | 2.11 |         4527.0 |     2509.0 | 1.80 |
| 64K |        31709.0 |    11707.0 | 2.71 |        18875.0 |    10119.0 | 1.87 |

Note the arm64 two-pass column improved along with the elementwise kernels, so
the ratio narrowed even though AXPY itself is unchanged.

## How to Reproduce

```bash
go test -bench=. -benchtime=300ms -benchmem -count=3
go test -bench=. -benchtime=300ms -count=3 -tags purego   # scalar baseline
```

For the arm64 path-crossover sweep, the reduction thresholds in `sum.s` and
`dotproduct.s` can be forced low (vector everywhere) or high (scalar
everywhere), and `BenchmarkSum_NEON_Direct` / `BenchmarkDotProduct_NEON_Direct`
in `arch/arm64/neon` run a size sweep dense around the crossover.

## How to Update

1. Run benchmarks on the target machine, on mains power if it is a laptop.
2. Check that untouched kernels still read ~1.00x before believing any number.
3. Replace the tables above with new results.
4. Update the environment section (date, Go version, CPU, OS).
