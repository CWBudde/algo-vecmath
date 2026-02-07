# algo-vecmath: Development Plan

## Overview

`algo-vecmath` is a standalone SIMD-accelerated vector math library for Go, extracted from `github.com/cwbudde/algo-dsp/internal/vecmath`.

**Module**: `github.com/cwbudde/algo-vecmath`

It provides element-wise arithmetic, fused operations, and reductions with architecture-specific backends (AVX2, SSE2, NEON) and pure-Go scalar fallbacks. Runtime CPU detection selects the fastest available path automatically.

---

## Current State

### Implemented

- **12 public functions** across 5 categories:
  - Arithmetic: `AddBlock`, `AddBlockInPlace`, `MulBlock`, `MulBlockInPlace`, `ScaleBlock`, `ScaleBlockInPlace`
  - Fused: `AddMulBlock`, `MulAddBlock`
  - Reductions: `Sum`, `DotProduct`, `MaxAbs`
  - Spectral: `Magnitude`, `Power`
- **4 architecture backends** with Go Plan 9 assembly:
  - `arch/amd64/avx2` (priority 20) -- 4x float64 per instruction
  - `arch/amd64/sse2` (priority 10) -- 2x float64 per instruction
  - `arch/arm64/neon` (priority 15) -- 2x float64 per instruction
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

- [ ] Run the full benchmark suite on at least two representative machines (amd64 AVX2-capable + arm64 NEON).
- [ ] Create `BENCHMARKS.md` with dated baselines, Go version, and hardware info.

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

## Exit Criteria

- [ ] No major regressions in allocations/op on key hot paths.
- [ ] `go test ./...` and `go test -tags purego ./...` pass on amd64 and arm64.
- [ ] `BENCHMARKS.md` exists with current baselines.
- [ ] v1.0.0 tagged and importable via `go get`.
