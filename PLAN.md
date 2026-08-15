# algo-vecmath: Development Plan

## Overview

`algo-vecmath` is a standalone SIMD-accelerated vector math library for Go, extracted from `github.com/cwbudde/algo-dsp/internal/vecmath`.

**Module**: `github.com/cwbudde/algo-vecmath`

It provides element-wise arithmetic, fused operations, and reductions with architecture-specific backends (AVX2, SSE2, NEON) and pure-Go scalar fallbacks. Runtime CPU detection selects the fastest available path automatically.

---

## Current State

### Implemented

- **14 public functions** across 6 categories:
  - Arithmetic: `AddBlock`, `AddBlockInPlace`, `MulBlock`, `MulBlockInPlace`, `ScaleBlock`, `ScaleBlockInPlace`
  - Fused: `AddMulBlock`, `MulAddBlock`
  - Reductions: `Sum`, `DotProduct`, `MaxAbs`
  - Spectral: `Magnitude`, `Power`
  - Modal oscillator (float32, generic backend only): `RotateDecayComplexF32`, `RotateDecayAccumulateF32`
- **4 architecture backends** with Go Plan 9 assembly:
  - `arch/amd64/avx2` (priority 20) -- 4x float64 per instruction
  - `arch/amd64/sse2` (priority 10) -- 2x float64 per instruction
  - `arch/arm64/neon` (priority 15) -- 2x float64 per instruction. Genuinely vector only
    since v0.1.3: before that, every kernel except `axpy.s` was a 2x-unrolled *scalar* loop
    (see Remaining Work section 6 for what is still scalar, and why)
  - `arch/generic` (priority 0) -- pure-Go scalar fallback
- **Registry-based dispatch** with runtime CPU feature detection (`cpu/`)
- **Build tag support**: `-tags=purego` forces generic-only path
- **Zero allocations** across all operations
- **Comprehensive tests**: parity tests between all backends, benchmarks for all operations at multiple sizes (16-65536 elements)

### Consumers

- `github.com/cwbudde/algo-dsp/dsp/window` -- window coefficient application
- `github.com/cwbudde/algo-dsp/dsp/spectrum` -- magnitude/power computation
- `github.com/cwbudde/algo-dsp/dsp/filter/fir` -- FIR dot product
- `github.com/cwbudde/algo-dsp/dsp/conv` -- direct convolution kernels
- `github.com/cwbudde/algo-dsp/dsp/filter/biquad` -- CPU feature detection via `cpu/`

---

## Remaining Work

### 1. Benchmark Regression Guard

- [ ] Choose a stable benchmark subset covering the hottest paths (e.g. `MulBlock`, `DotProduct`, `Magnitude` at 1024 and 65536 elements).
- [ ] Define a regression threshold policy (ns/op and allocs/op) and document how to update baselines.
- [ ] Add a CI-friendly target (e.g. `just bench-ci`) that runs quickly and emits a machine-readable report.
- [ ] Wire into CI as advisory output (make blocking only after v1.0 if desired).

### 2. Benchmark Baselines

- [x] Run the full benchmark suite on at least two representative machines (amd64 AVX2-capable + arm64 NEON).
- [x] Create `BENCHMARKS.md` with dated baselines, Go version, and hardware info.
- [ ] Re-measure the arm64 column on a *mains-powered, idle* machine. The v0.1.3 numbers were
      taken on a borrowed unplugged MacBook where run-to-run variance reached 1.58x on
      identical code; the headline wins are far outside that band but the sub-1.3x rows are
      not. See the "how to not misread this" section of `BENCHMARKS.md`.

### 3. Optional: Legacy ASM → Go Assembly Ports

Goal: Port a _small_ set of high-value kernels from `mfw/legacy/Source/ASM/` into Go Plan 9 assembly, guarded by build tags and backed by scalar references. Only pursue if profiling shows meaningful headroom.

- [ ] Decide and document the target list (keep it minimal):
  - [ ] TPDF dither/noise kernel (if required by downstream apps)
  - [ ] Any remaining hot loop that materially impacts real workloads
- [ ] For each selected target:
  - [ ] Confirm scalar reference is the source of truth.
  - [ ] Add golden vectors (generated once from a legacy `mfw` build) + parity tests.
  - [ ] Implement amd64 (SSE2/AVX2) and arm64 (NEON) variants behind `!purego` tags.
  - [ ] Add a focused microbenchmark and document the speedup and constraints.
- [ ] Per-port exit criteria: parity within tolerance + >=2x speedup in its microbenchmark.

### 4. API Stabilization and v1.0

- [ ] Review public API surface for consistency and completeness.
- [ ] Final CI pass (`go test ./...` and `go test -tags purego ./...`).
- [ ] Tag and publish `v1.0.0`.
- [ ] Verify Go module proxy indexing.

---

### 5. Modal/Quadrature Oscillator Kernels (for `algo-dsp` + `algo-piano`)

Goal: provide SIMD-ready primitives for damped complex-rotator banks used by modal synthesis.

- [ ] Add scalar reference kernels (generic backend) for complex rotation + decay updates.
- [ ] Add `float32`-first APIs (realtime synthesis hot path), with optional `float64` counterparts where useful.
- [ ] Finalize and document SIMD-friendly memory layout (default SoA):
  - [ ] `re[]`, `im[]`, `cosW[]`, `sinW[]`, `decay[]`, optional `gain[]`
  - [ ] Optional adapter helpers for interleaved layouts if callers require them.
- [ ] Implement architecture backends:
  - [ ] amd64 AVX2
  - [ ] amd64 SSE2 fallback
  - [ ] arm64 NEON
- [ ] Add fused helper kernels needed by modal-bank loops (e.g. rotate+decay+accumulate variants) if profiling justifies them.
- [ ] Add parity/stress tests:
  - [ ] Random vectors vs scalar reference
  - [ ] Long-tail decay stability / denormal behavior
  - [ ] NaN/Inf propagation policy documented and tested
- [ ] Add focused benchmarks for modal sizes (8/16/24/32 modes, block size 128 and 256).
- [ ] Publish recommended calling pattern for integration in `algo-dsp`.

Suggested API sketch (to finalize during implementation):

```go
// Rotates and damps a bank of complex oscillators in place.
func RotateDecayComplexF32(re, im, cosW, sinW, decay []float32)

// Optional fused variant: updates state and accumulates weighted real part.
func RotateDecayAccumulateF32(dst []float32, re, im, cosW, sinW, decay, gain []float32)
```

### 5.1 Concrete issue backlog (modal/quadrature kernels)

These tickets are intended to be executed before `algo-dsp` lands the high-level modal oscillator package.

- [x] `VEC-301` — Add scalar reference kernels for complex rotate+decay (`float32`).
  - Scope: generic backend kernels for SoA arrays (`re`, `im`, `cosW`, `sinW`, `decay`).
  - Acceptance: deterministic reference tests and API docs.
  - Depends on: none.
- [x] `VEC-302` — Add `RotateDecayComplexF32` public API.
  - Scope: in-place update API with strict length/aliasing checks.
  - Acceptance: parity vs `VEC-301` across random and edge-case vectors.
  - Depends on: `VEC-301`.
- [x] `VEC-303` — Add fused accumulate API (`RotateDecayAccumulateF32`).
  - Scope: update state and accumulate weighted real-part contribution.
  - Acceptance: parity tests vs scalar composition; zero allocations.
  - Depends on: `VEC-302`.
- [x] `VEC-304` — amd64 AVX2 backend for rotate/accumulate kernels.
  - Scope: assembly-backed or vectorized backend for AVX2 path.
  - Acceptance: microbench speedup vs generic on AVX2 machine; parity tests pass.
  - Depends on: `VEC-302`, `VEC-303`.
- [x] `VEC-305` — amd64 SSE2 fallback backend for rotate/accumulate kernels.
  - Scope: SSE2 implementation for non-AVX2 amd64 targets.
  - Acceptance: parity tests pass; benchmark shows non-regression vs generic.
  - Depends on: `VEC-302`, `VEC-303`.
- [x] `VEC-306` — arm64 NEON backend for rotate/accumulate kernels.
  - Scope: NEON implementation for arm64 targets.
  - Acceptance: parity tests pass; benchmark speedup on arm64 NEON.
  - Depends on: `VEC-302`, `VEC-303`.
- [x] `VEC-307` — Modal-kernel benchmark matrix + baselines.
  - Scope: benchmark suite for modal sizes 8/16/24/32 and block 128/256.
  - Acceptance: baseline table committed (Go version, CPU, date).
  - Depends on: `VEC-302`.
- [ ] `VEC-308` — Long-tail stability / denormal behavior tests.
  - Scope: long-run decay tests with denormal-sensitive tails.
  - Acceptance: no NaN/Inf regressions and documented denormal behavior.
  - Depends on: `VEC-302`.

---

### 6. Kernel backlog from the arm64 vectorisation round (v0.1.3)

Opened 2026-08-15, after the round that rewrote `scale.s`, `add.s`, `mul.s`, `fused.s`,
`sum.s` and `dotproduct.s` as true SIMD. Ordered by value to the known consumers.

**6a. New primitives that downstream code is waiting on.** Both are requested by `algo-dsp`
Phase 41c; see that repo's PLAN.md for the exact call sites.

- [ ] `MulComplexBlock` over `[]complex128` (plus a `complex64` twin). Eight call sites in
      `algo-dsp`, including `dsp/conv/partitioned.go:150`/`:166` — the hottest loop there for
      long-IR convolution. Go compiles a complex multiply to 4 multiplies + 2 adds with no
      vectorization. **No layout work is needed**: `[]complex128` is bit-identical to
      interleaved `[]float64` and `algo-dsp` already reinterprets it via `unsafe.Slice`.
- [ ] `SumSquaredDiff` — the YIN difference function in `algo-dsp` is ~640k FLOPs per frame,
      the densest scalar loop in that repo.

**6b. arm64 kernels deliberately left scalar in v0.1.3.** Each is blocked on a specific
missing mnemonic, recorded here so the next round does not re-derive it. The complete set of
V-prefixed FP arithmetic mnemonics the Go arm64 assembler accepts is `VFMLA`/`VFMLS` and
nothing else (`VADD`/`VSUB`/`VUMAX` are integer-lane ops) — verified against
`$GOROOT/src/cmd/internal/obj/arm64/anames.go`.

- [ ] `maxabs.s` — no vector `FMAX` or `FABS`, and NEON has no 64-bit-lane integer max, so the
      bit-pattern trick is unavailable too. It is also worse than it looks today: a **single**
      accumulator held in a *general-purpose* register, paying two cross-domain
      `VMOV V0.D[k], R4` extractions per pair inside the loop. Even without vector max, going
      to 4 accumulators and keeping them in V registers should be worth something.
- [ ] `magnitude.s`, `power.s` — no vector `FSQRT`.
- [ ] `dither.s` — serial by construction (noise shaping feedback); not a candidate.
- [ ] float32 vector kernels. `VFMLA` does accept `S4` for 4-lane float32 FMA; the vector
      form simply has not been written. This is the cheapest remaining win and would double
      the lane count for the modal oscillator kernels of section 5.

**6c. Method, so the next round starts where this one ended.**

- [ ] Any new elementwise kernel can be expressed bit-exactly through `VFMLA` alone, because
      each is an affine combination: `a*b` is `acc = -0.0; acc += a*b`, `a+b` is
      `acc = b; acc += a*1.0`, and `a*b+c` is a *single* instruction. FMA rounds once and
      `a*1.0` is exact, so these match `FMULD`/`FADDD` exactly. **The additive identity must
      be `-0.0`, not `+0.0`** — with `+0.0` a product of `-0.0` comes back `+0.0` and diverges
      from `FMULD` on the sign of zero. `signedzero_test.go` is the guard for that and must be
      extended alongside any new multiply kernel.
- [ ] Watch for F/V register aliasing. `Fn` is the low 64 bits of `Vn`, and a scalar FP write
      to `Fn` **zeroes the upper half of `Vn`**. Both bugs introduced during the v0.1.3 rewrite
      were this, in different kernels. Keep scalar-tail operands in registers the vector loop
      does not touch.
- [ ] Every new reduction needs a measured small-`n` crossover, not a guessed one. Vectorising
      `Sum` and `DotProduct` made them *slower* below ~100 elements (0.29x at n=16) because of
      fixed prologue and horizontal-fold cost; both now branch to a scalar path at a measured
      threshold (128 for `DotProduct`, 192 for `Sum`). That range is real — `algo-dsp`'s
      `filter/fir` calls a reduction per output sample from 32 taps up.
- [ ] Extend the length sweeps whenever an unroll factor changes. The v0.1.3 sweep topped out
      at 1000, a multiple of 8, so the vector path's `len%8` tail had **zero** coverage once
      the threshold branch was added.

## Exit Criteria

- [ ] No major regressions in allocations/op on key hot paths.
- [ ] `go test ./...` and `go test -tags purego ./...` pass on amd64 and arm64.
- [ ] `BENCHMARKS.md` exists with current baselines.
- [ ] v1.0.0 tagged and importable via `go get`.
