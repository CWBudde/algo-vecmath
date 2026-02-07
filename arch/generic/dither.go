package generic

// GenerateTPDF fills dst with TPDF (Triangular PDF) noise: dst[i] = tpdf_noise * scale.
//
// Uses a 256-byte circular buffer PRNG with additive feedback. For each output
// sample, two random int32 values are read from the buffer, shifted right by 1
// (to prevent overflow), summed (giving triangular PDF), and scaled.
//
// This is the pure Go fallback implementation.
func GenerateTPDF(dst []float64, scale float64, field *[64]uint32, pos int) int {
	for i := range dst {
		var sum int32

		// Average 1: read, shift, feedback, advance
		val := field[pos]
		sum += int32(val) >> 1
		prev := (pos - 1) & 63
		field[prev] += val
		pos = (pos + 2) & 63

		// Average 2: read, shift, feedback, advance
		val = field[pos]
		sum += int32(val) >> 1
		prev = (pos - 1) & 63
		field[prev] += val
		pos = (pos + 2) & 63

		dst[i] = float64(sum) * scale
	}
	return pos
}

// AddDitherTPDF adds TPDF noise to dst: dst[i] += tpdf_noise * scale.
//
// Same PRNG algorithm as GenerateTPDF but adds noise to existing values.
// This is the pure Go fallback implementation.
func AddDitherTPDF(dst []float64, scale float64, field *[64]uint32, pos int) int {
	for i := range dst {
		var sum int32

		// Average 1: read, shift, feedback, advance
		val := field[pos]
		sum += int32(val) >> 1
		prev := (pos - 1) & 63
		field[prev] += val
		pos = (pos + 2) & 63

		// Average 2: read, shift, feedback, advance
		val = field[pos]
		sum += int32(val) >> 1
		prev = (pos - 1) & 63
		field[prev] += val
		pos = (pos + 2) & 63

		dst[i] += float64(sum) * scale
	}
	return pos
}
