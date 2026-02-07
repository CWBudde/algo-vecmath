# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

`algo-vecmath` is a Go package providing SIMD-optimized vector math operations on `[]float64` slices for DSP workloads. It targets amd64 (AVX2, SSE2) and arm64 (NEON) with a pure Go generic fallback.

## Build & Test Commands

```bash
# Run all tests
go test ./...

# Run a single test
go test -run TestAddBlock ./...

# Run tests with pure Go fallback only (no assembly)
go test -tags purego ./...

# Run benchmarks
go test -bench=. -benchmem ./...

# Run benchmarks for a specific operation
go test -bench=BenchmarkAddBlock -benchmem

# Verify assembly compiles and test a specific arch package
go test ./arch/amd64/avx2/...

# Disassemble to verify emitted instructions
go tool objdump -s 'addBlockAVX2' vecmath.test
```

## Architecture

### Dispatch System (registry pattern)

The package uses a **registry-based dispatch** with one-time init:

1. **Registration**: Architecture-specific packages (`arch/{amd64/avx2, amd64/sse2, arm64/neon, generic}`) register themselves into `internal/registry.Global` via `init()` functions with a priority and required `cpu.SIMDLevel`.
2. **Platform wiring**: Build-tag-guarded files (`init_amd64.go`, `init_arm64.go`, `init_generic.go`, `init_purego.go`) use blank imports to pull in the correct arch packages for the build target.
3. **Lazy lookup**: Each top-level operation file (e.g., `add.go`, `mul.go`) uses `sync.Once` to call `registry.Global.Lookup(cpu.DetectFeatures())` on first use, caching the resolved function pointer for zero-overhead subsequent calls.

Priority order: AVX2 (20) > NEON (15) > SSE2 (10) > generic (0).

### Adding a New Operation

1. Add the function pointer field to `internal/registry.OpEntry`.
2. Implement in each arch package (`arch/generic/`, `arch/amd64/avx2/`, `arch/amd64/sse2/`, `arch/arm64/neon/`).
3. Register it in each arch's `register.go` `init()`.
4. Create a top-level dispatch file (e.g., `newop.go`) with `sync.Once` + cached function pointer pattern matching existing files like `add.go`.
5. Add tests: `newop_test.go` (correctness against reference impl), `newop_bench_test.go` (benchmarks using `benchSizes` from `testutil_test.go`).

### Assembly (.s files)

All SIMD kernels use **Go Plan 9-style assembly** with ABI0 (stack-based calling convention):
- AVX2 routines process 4 float64s per iteration (256-bit YMM registers), with scalar tail loops.
- SSE2 routines process 2 float64s per iteration (128-bit XMM registers).
- NEON routines process 2 float64s per iteration (128-bit V registers).
- All asm functions are declared with `//go:noescape` in companion `.go` files.
- Every AVX2 function must call `VZEROUPPER` before `RET`.
- Go wrapper functions handle length validation and empty-slice early returns; the asm only handles the math.

### Key Packages

- **`cpu/`**: CPU feature detection (wraps `golang.org/x/sys/cpu`), with `SetForcedFeatures()`/`ResetDetection()` for testing.
- **`internal/registry/`**: `OpEntry` struct with typed function pointers for all operations; `OpRegistry` with `Register()`/`Lookup()`.
- **`arch/`**: Per-architecture implementations. Each has a `register.go` for init registration plus one `.go`+`.s` file pair per operation.

### Test Conventions

- Correctness tests compare against inline reference implementations (e.g., `addBlockRef`).
- Tests cover boundary sizes: 0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 100, 1000 (SIMD lane boundaries).
- `closeEnough()` in `testutil_test.go` for floating-point comparison (epsilon 1e-14).
- `implementation_test.go` tests forced dispatch to specific backends (generic, AVX2, SSE2) via `cpu.SetForcedFeatures()`.
- Benchmarks use shared `benchSizes` (16 to 64K) and report `b.SetBytes` for throughput.

### Build Tags

- Default: full SIMD support for the target architecture.
- `purego`: forces pure Go generic implementation only (no assembly).
- Assembly files use `//go:build !purego && amd64` (or `arm64`).
