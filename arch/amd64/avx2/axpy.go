//go:build !purego && amd64

package avx2

// AddScaledBlockInPlace accumulates a scaled block: dst[i] += src[i] * scale.
// Slices must have equal length. Panics if lengths differ.
// Uses AVX2 SIMD instructions to process 4 float64 values at once.
func AddScaledBlockInPlace(dst, src []float64, scale float64) {
	if len(dst) != len(src) {
		panic("vecmath: slice length mismatch")
	}
	if len(dst) == 0 {
		return
	}
	addScaledBlockInPlaceAVX2(dst, src, scale)
}

// Assembly function declaration (implemented in axpy.s)

//go:noescape
func addScaledBlockInPlaceAVX2(dst, src []float64, scale float64)
