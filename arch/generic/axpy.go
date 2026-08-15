package generic

// AddScaledBlockInPlace accumulates a scaled block: dst[i] += src[i] * scale.
// Slices must have equal length. Panics if lengths differ.
// This is the pure Go fallback implementation.
func AddScaledBlockInPlace(dst, src []float64, scale float64) {
	if len(dst) != len(src) {
		panic("vecmath: slice length mismatch")
	}
	for i := range dst {
		dst[i] += src[i] * scale
	}
}
