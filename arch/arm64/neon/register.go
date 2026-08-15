//go:build arm64 && !purego

package neon

import (
	"github.com/cwbudde/algo-vecmath/cpu"
	"github.com/cwbudde/algo-vecmath/internal/registry"
)

// init registers the NEON-optimized implementations with the vecmath registry.
//
// NEON (ARM Advanced SIMD) provides 128-bit SIMD operations and is mandatory
// on ARMv8 (arm64), so it's available on all arm64 CPUs. NEON processes 2 float64
// values at once.
//
// Priority: 15 (medium-high - ARM's equivalent to AVX/AVX2)
func init() {
	registry.Global.Register(registry.OpEntry{
		Name:      "neon",
		SIMDLevel: cpu.SIMDNEON,
		Priority:  15,

		// Arithmetic operations
		AddBlock:          AddBlock,
		AddBlockInPlace:   AddBlockInPlace,
		MulBlock:          MulBlock,
		MulBlockInPlace:   MulBlockInPlace,
		ScaleBlock:        ScaleBlock,
		ScaleBlockInPlace: ScaleBlockInPlace,

		// Fused operations
		AddMulBlock:           AddMulBlock,
		MulAddBlock:           MulAddBlock,
		AddScaledBlockInPlace: AddScaledBlockInPlace,

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

		// Modal oscillator operations (float32) are not registered here, so
		// arm64 dispatches them to the generic implementation.
		//
		// The reason is narrower than it might look. A *scalar* assembly
		// version is ruled out: it cannot match the FMA contraction the
		// compiler applies to the generic Go code, which is observable under
		// cancellation. A vector version is not ruled out -- VFMLA does accept
		// the S4 arrangement, giving 4-lane float32 FMA, and being an FMA it
		// would match that contraction rather than diverge from it. It simply
		// has not been written or measured yet.
	})
}
