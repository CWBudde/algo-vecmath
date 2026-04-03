package generic

// RotateDecayComplexF32 rotates and damps a bank of complex oscillators in place.
// For each i: re[i], im[i] = decay[i] * (re[i]*cosW[i] - im[i]*sinW[i]),
//
//	decay[i] * (re[i]*sinW[i] + im[i]*cosW[i])
//
// All slices must have equal length. Panics if lengths differ.
// This is the pure Go scalar fallback implementation.
func RotateDecayComplexF32(re, im, cosW, sinW, decay []float32) {
	n := len(re)
	if len(im) != n || len(cosW) != n || len(sinW) != n || len(decay) != n {
		panic("vecmath: slice length mismatch")
	}

	for i := range n {
		r := re[i]
		m := im[i]
		c := cosW[i]
		s := sinW[i]
		d := decay[i]
		re[i] = d * (r*c - m*s)
		im[i] = d * (r*s + m*c)
	}
}

// RotateDecayAccumulateF32 updates oscillator state and accumulates the weighted real part.
// For each i: re[i], im[i] are rotated and decayed, then dst[i] += gain[i] * re[i].
// All slices must have equal length. Panics if lengths differ.
// This is the pure Go scalar fallback implementation.
func RotateDecayAccumulateF32(dst []float32, re, im, cosW, sinW, decay, gain []float32) {
	n := len(re)
	if len(im) != n || len(cosW) != n || len(sinW) != n || len(decay) != n || len(gain) != n || len(dst) != n {
		panic("vecmath: slice length mismatch")
	}

	for i := range n {
		r := re[i]
		m := im[i]
		c := cosW[i]
		s := sinW[i]
		d := decay[i]
		re[i] = d * (r*c - m*s)
		im[i] = d * (r*s + m*c)
		dst[i] += gain[i] * re[i]
	}
}
