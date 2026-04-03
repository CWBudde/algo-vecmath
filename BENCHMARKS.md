# Benchmark Baselines

## Environment

| Field        | Value                                    |
|--------------|------------------------------------------|
| Date         | 2026-04-03                               |
| Go version   | go1.25.0 linux/amd64                     |
| CPU          | 12th Gen Intel Core i7-1255U (Alder Lake)|
| SIMD backend | AVX2                                     |
| OS           | Linux 6.8.0-106-generic                  |

> **Note:** This is a mobile CPU with P-core/E-core hybrid architecture
> and dynamic turbo boost. Results may vary between runs due to thermal
> throttling and core scheduling. Best-of-3 values are reported below.

## Modal Oscillator Kernels (float32, AVX2)

All operations report **0 B/op** and **0 allocs/op**.

### RotateDecayComplexF32

In-place complex rotation + decay for a bank of oscillators.

| Partials | ns/op (best) | MB/s (best) |
|---------:|-------------:|------------:|
|        8 |          196 |         816 |
|       16 |          407 |         786 |
|       24 |          566 |         848 |
|       32 |          783 |         817 |
|       64 |         1334 |         959 |
|      128 |         2178 |        1175 |
|      256 |         6528 |         784 |

### RotateDecayAccumulateF32

Fused rotate + decay + weighted accumulation into output buffer.

| Partials | ns/op (best) | MB/s (best) |
|---------:|-------------:|------------:|
|        8 |          233 |         961 |
|       16 |          510 |         879 |
|       24 |          781 |         860 |
|       32 |          819 |        1093 |
|       64 |         1442 |        1242 |
|      128 |         2013 |        1781 |
|      256 |         7152 |        1002 |

## How to Reproduce

```bash
go test -bench=BenchmarkRotateDecay -benchmem -count=3
```

## How to Update

1. Run benchmarks on the target machine.
2. Replace the table above with new results.
3. Update the environment section (date, Go version, CPU, OS).
