//go:build !purego && amd64

package sse2

// GenerateTPDF fills dst with TPDF noise: dst[i] = tpdf_noise * scale.
// Uses a 256-byte circular buffer PRNG with additive feedback.
// Returns the new position in the field.
func GenerateTPDF(dst []float64, scale float64, field *[64]uint32, pos int) int {
	if len(dst) == 0 {
		return pos
	}
	return generateTPDFSSE2(dst, scale, field, pos)
}

// AddDitherTPDF adds TPDF noise to dst: dst[i] += tpdf_noise * scale.
// Uses a 256-byte circular buffer PRNG with additive feedback.
// Returns the new position in the field.
func AddDitherTPDF(dst []float64, scale float64, field *[64]uint32, pos int) int {
	if len(dst) == 0 {
		return pos
	}
	return addDitherTPDFSSE2(dst, scale, field, pos)
}

//go:noescape
func generateTPDFSSE2(dst []float64, scale float64, field *[64]uint32, pos int) int

//go:noescape
func addDitherTPDFSSE2(dst []float64, scale float64, field *[64]uint32, pos int) int
