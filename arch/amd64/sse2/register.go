//go:build amd64 && !purego

package sse2

import (
	"github.com/cwbudde/algo-vecmath/cpu"
	"github.com/cwbudde/algo-vecmath/internal/registry"
)

// init registers the SSE2-optimized implementations with the vecmath registry.
//
// SSE2 provides 128-bit SIMD operations and is part of the x86-64 baseline,
// so it's available on all amd64 CPUs. SSE2 processes 2 float64 values at once.
//
// Priority: 10 (medium - preferred over generic, but lower than AVX2)
func init() {
	registry.Global.Register(registry.OpEntry{
		Name:      "sse2",
		SIMDLevel: cpu.SIMDSSE2,
		Priority:  10,

		// Arithmetic operations
		AddBlock:          AddBlock,
		AddBlockInPlace:   AddBlockInPlace,
		MulBlock:          MulBlock,
		MulBlockInPlace:   MulBlockInPlace,
		ScaleBlock:        ScaleBlock,
		ScaleBlockInPlace: ScaleBlockInPlace,

		// Fused operations
		AddMulBlock: AddMulBlock,
		MulAddBlock: MulAddBlock,

		// Reduction operations
		MaxAbs:     MaxAbs,
		Sum:        Sum,
		DotProduct: DotProduct,

		// Spectrum operations
		Magnitude: Magnitude,
		Power:     Power,

		// Dither operations
		GenerateTPDF:  GenerateTPDF,
		AddDitherTPDF: AddDitherTPDF,

		// Modal oscillator operations (float32)
		RotateDecayComplexF32:    RotateDecayComplexF32,
		RotateDecayAccumulateF32: RotateDecayAccumulateF32,
	})
}
