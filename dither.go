package vecmath

import (
	"sync"

	"github.com/cwbudde/algo-vecmath/cpu"
	"github.com/cwbudde/algo-vecmath/internal/registry"
)

// tpdfNorm normalizes the int32 sum range to [-1, +1].
// TPDF sums two int32 values each shifted right by 1, giving a range of approximately [-2^31, 2^31].
const tpdfNorm = 1.0 / float64(int64(1) << 31)

var (
	generateTPDFImpl  func([]float64, float64, *[64]uint32, int) int
	addDitherTPDFImpl func([]float64, float64, *[64]uint32, int) int
	ditherInitOnce    sync.Once
)

func initDitherOperations() {
	features := cpu.DetectFeatures()
	entry := registry.Global.Lookup(features)
	if entry == nil {
		panic("vecmath: no dither implementation registered")
	}
	if entry.GenerateTPDF == nil || entry.AddDitherTPDF == nil {
		panic("vecmath: selected implementation missing dither operations")
	}
	generateTPDFImpl = entry.GenerateTPDF
	addDitherTPDFImpl = entry.AddDitherTPDF
}

// GenerateTPDF fills dst with TPDF (Triangular Probability Density Function) noise.
//
// Each output sample is the sum of two uniform random values, producing a triangular
// probability distribution. Output values are in the range [-gain, +gain].
// A gain of 1.0 produces 2 LSB peak-to-peak dither for a full-scale signal.
//
// The state parameter must be created with NewDitherState and holds the PRNG state.
// It is updated in place after each call, so successive calls produce different noise.
func GenerateTPDF(dst []float64, gain float64, state *DitherState) {
	if len(dst) == 0 {
		return
	}
	ditherInitOnce.Do(initDitherOperations)
	scale := gain * tpdfNorm
	state.pos = generateTPDFImpl(dst, scale, &state.field, state.pos)
}

// AddDitherTPDF adds TPDF dither noise to dst in place: dst[i] += noise * gain.
//
// This is the typical operation for applying dither before quantization.
// A gain of 1.0 adds 2 LSB peak-to-peak TPDF dither for a full-scale signal.
//
// The state parameter must be created with NewDitherState and holds the PRNG state.
// It is updated in place after each call.
func AddDitherTPDF(dst []float64, gain float64, state *DitherState) {
	if len(dst) == 0 {
		return
	}
	ditherInitOnce.Do(initDitherOperations)
	scale := gain * tpdfNorm
	state.pos = addDitherTPDFImpl(dst, scale, &state.field, state.pos)
}
