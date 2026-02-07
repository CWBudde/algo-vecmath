# vecmath

SIMD-accelerated vector math operations on `[]float64` slices for Go.

Provides element-wise arithmetic, reductions, and spectrum operations commonly needed in DSP and signal processing. The best implementation is selected automatically at runtime based on CPU features, with a pure Go fallback for portability.

## Supported Platforms

| Architecture | Instruction Set | Vector Width | Priority |
|---|---|---|---|
| amd64 | AVX2 | 4 x float64 (256-bit) | Preferred |
| amd64 | SSE2 | 2 x float64 (128-bit) | Baseline |
| arm64 | NEON | 2 x float64 (128-bit) | Preferred |
| Any | Pure Go | Scalar | Fallback |

## Install

```
go get github.com/cwbudde/algo-vecmath
```

Requires Go 1.25+.

## Usage

```go
import "github.com/cwbudde/algo-vecmath"

dst := make([]float64, 1024)
a := make([]float64, 1024)
b := make([]float64, 1024)

// Element-wise addition: dst[i] = a[i] + b[i]
vecmath.AddBlock(dst, a, b)

// In-place scaling: dst[i] *= 0.5
vecmath.ScaleBlockInPlace(dst, 0.5)

// Reduction: peak absolute value
peak := vecmath.MaxAbs(dst)
```

No setup required. The first call to any operation detects CPU features and caches a direct function pointer. All subsequent calls go through that pointer with zero dispatch overhead.

## Operations

### Element-wise Arithmetic

| Function | Operation |
|---|---|
| `AddBlock(dst, a, b)` | `dst[i] = a[i] + b[i]` |
| `AddBlockInPlace(dst, src)` | `dst[i] += src[i]` |
| `MulBlock(dst, a, b)` | `dst[i] = a[i] * b[i]` |
| `MulBlockInPlace(dst, src)` | `dst[i] *= src[i]` |
| `ScaleBlock(dst, src, s)` | `dst[i] = src[i] * s` |
| `ScaleBlockInPlace(dst, s)` | `dst[i] *= s` |

### Fused Operations

Fused operations reduce memory traffic by combining two operations in a single pass.

| Function | Operation |
|---|---|
| `AddMulBlock(dst, a, b, s)` | `dst[i] = (a[i] + b[i]) * s` |
| `MulAddBlock(dst, a, b, c)` | `dst[i] = a[i] * b[i] + c[i]` |

### Reductions

| Function | Operation |
|---|---|
| `Sum(x)` | `sum(x[i])` |
| `MaxAbs(x)` | `max(\|x[i]\|)` |
| `DotProduct(a, b)` | `sum(a[i] * b[i])` |

### Spectrum

| Function | Operation |
|---|---|
| `Magnitude(dst, re, im)` | `dst[i] = sqrt(re[i]^2 + im[i]^2)` |
| `Power(dst, re, im)` | `dst[i] = re[i]^2 + im[i]^2` |

## Properties

- **Zero allocations** in all operations.
- **Concurrent-safe** when goroutines operate on separate slices.
- **Panics** on slice length mismatch (element-wise and fused operations).

## Build Tags

```bash
# Default: automatic SIMD selection
go build

# Force pure Go (no assembly)
go build -tags purego
```

## Benchmarks

```bash
go test -bench=. -benchmem
```

On amd64 with AVX2, expect 2-5x throughput improvement over scalar Go for large slices.

## License

See [LICENSE](LICENSE) for details.
