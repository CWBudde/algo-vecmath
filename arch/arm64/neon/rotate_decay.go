//go:build !purego && arm64

package neon

// RotateDecayComplexF32 rotates and damps a bank of complex oscillators in place.
// Uses ARM64 NEON SIMD instructions to process 4 float32 values at once.
// All slices must have equal length. Panics if lengths differ.
func RotateDecayComplexF32(re, im, cosW, sinW, decay []float32) {
	n := len(re)
	if len(im) != n || len(cosW) != n || len(sinW) != n || len(decay) != n {
		panic("vecmath: slice length mismatch")
	}
	if n == 0 {
		return
	}
	rotateDecayComplexF32NEON(re, im, cosW, sinW, decay)
}

// RotateDecayAccumulateF32 updates oscillator state and accumulates the weighted real part.
// Uses ARM64 NEON SIMD instructions to process 4 float32 values at once.
// All slices must have equal length. Panics if lengths differ.
func RotateDecayAccumulateF32(dst []float32, re, im, cosW, sinW, decay, gain []float32) {
	n := len(re)
	if len(im) != n || len(cosW) != n || len(sinW) != n || len(decay) != n || len(gain) != n || len(dst) != n {
		panic("vecmath: slice length mismatch")
	}
	if n == 0 {
		return
	}
	rotateDecayAccumulateF32NEON(dst, re, im, cosW, sinW, decay, gain)
}

//go:noescape
func rotateDecayComplexF32NEON(re, im, cosW, sinW, decay []float32)

//go:noescape
func rotateDecayAccumulateF32NEON(dst []float32, re, im, cosW, sinW, decay, gain []float32)
