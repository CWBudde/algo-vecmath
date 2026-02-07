package vecmath

import "math/rand"

// DitherState holds the PRNG state for TPDF dither generation.
//
// It uses a 256-byte circular buffer with additive feedback, matching the
// proven approach from professional audio DSP implementations. The buffer
// must be seeded before use via NewDitherState.
type DitherState struct {
	field [64]uint32 // 256-byte circular buffer of random values
	pos   int        // current index into field (0-63)
}

// NewDitherState creates a new DitherState seeded from the given seed value.
// Different seeds produce different (deterministic) noise sequences.
func NewDitherState(seed int64) *DitherState {
	rng := rand.New(rand.NewSource(seed))
	state := &DitherState{}
	for i := range state.field {
		state.field[i] = rng.Uint32()
	}
	return state
}
