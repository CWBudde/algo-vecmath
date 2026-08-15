//go:build !purego && arm64

package neon

// AddScaledBlockInPlace accumulates a scaled block: dst[i] += src[i] * scale.
// Slices must have equal length. Panics if lengths differ.
// Uses ARM NEON SIMD instructions to process 4 float64 values per iteration.
func AddScaledBlockInPlace(dst, src []float64, scale float64) {
	if len(dst) != len(src) {
		panic("vecmath: slice length mismatch")
	}
	if len(dst) == 0 {
		return
	}
	addScaledBlockInPlaceNEON(dst, src, scale)
}

// Assembly function declaration (implemented in axpy.s)

//go:noescape
func addScaledBlockInPlaceNEON(dst, src []float64, scale float64)
