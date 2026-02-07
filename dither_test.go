package vecmath

import (
	"math"
	"testing"
)

// Reference implementation for GenerateTPDF (matches arch/generic/dither.go)
func generateTPDFRef(dst []float64, scale float64, field *[64]uint32, pos int) int {
	for i := range dst {
		var sum int32

		val := field[pos]
		sum += int32(val) >> 1
		prev := (pos - 1) & 63
		field[prev] += val
		pos = (pos + 2) & 63

		val = field[pos]
		sum += int32(val) >> 1
		prev = (pos - 1) & 63
		field[prev] += val
		pos = (pos + 2) & 63

		dst[i] = float64(sum) * scale
	}
	return pos
}

// copyField returns a copy of a DitherState field
func copyField(field [64]uint32) [64]uint32 {
	var cp [64]uint32
	copy(cp[:], field[:])
	return cp
}

func TestGenerateTPDF(t *testing.T) {
	sizes := []int{0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 100, 1000}

	for _, n := range sizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			state := NewDitherState(42)
			dst := make([]float64, n)
			expected := make([]float64, n)

			// Run reference on a copy of the state
			refField := copyField(state.field)
			refPos := state.pos
			refPos = generateTPDFRef(expected, 1.0*tpdfNorm, &refField, refPos)

			GenerateTPDF(dst, 1.0, state)

			for i := range dst {
				if !closeEnough(dst[i], expected[i]) {
					t.Errorf("GenerateTPDF[%d]: got %v, want %v", i, dst[i], expected[i])
				}
			}

			// Verify state was updated
			if n > 0 && state.pos != refPos {
				t.Errorf("pos: got %d, want %d", state.pos, refPos)
			}
		})
	}
}

func TestAddDitherTPDF(t *testing.T) {
	sizes := []int{0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 100, 1000}

	for _, n := range sizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			state := NewDitherState(42)

			// Prepare dst with known values
			dst := make([]float64, n)
			expected := make([]float64, n)
			for i := range dst {
				dst[i] = float64(i) * 0.01
				expected[i] = dst[i]
			}

			// Run reference on a copy of the state
			refField := copyField(state.field)
			refPos := state.pos
			for i := range expected {
				var sum int32
				val := refField[refPos]
				sum += int32(val) >> 1
				prev := (refPos - 1) & 63
				refField[prev] += val
				refPos = (refPos + 2) & 63

				val = refField[refPos]
				sum += int32(val) >> 1
				prev = (refPos - 1) & 63
				refField[prev] += val
				refPos = (refPos + 2) & 63

				expected[i] += float64(sum) * 1.0 * tpdfNorm
			}

			AddDitherTPDF(dst, 1.0, state)

			for i := range dst {
				if !closeEnough(dst[i], expected[i]) {
					t.Errorf("AddDitherTPDF[%d]: got %v, want %v", i, dst[i], expected[i])
				}
			}
		})
	}
}

func TestGenerateTPDFStatistics(t *testing.T) {
	const n = 100000
	state := NewDitherState(12345)
	dst := make([]float64, n)

	GenerateTPDF(dst, 1.0, state)

	// Compute mean
	var sum float64
	for _, v := range dst {
		sum += v
	}
	mean := sum / float64(n)

	// Mean should be approximately 0 (generous tolerance for circular buffer PRNG)
	if math.Abs(mean) > 0.1 {
		t.Errorf("mean = %v, want approximately 0", mean)
	}

	// Compute variance
	var varSum float64
	for _, v := range dst {
		d := v - mean
		varSum += d * d
	}
	variance := varSum / float64(n)

	// TPDF variance for range [-1, 1]: 1/6 ≈ 0.1667
	// Allow generous tolerance for PRNG-based values
	if variance < 0.01 || variance > 0.5 {
		t.Errorf("variance = %v, want in range [0.01, 0.5]", variance)
	}

	// All values should be within reasonable range
	for i, v := range dst {
		if v > 1.5 || v < -1.5 {
			t.Errorf("dst[%d] = %v, out of expected range [-1.5, 1.5]", i, v)
			break
		}
	}
}

func TestGenerateTPDFGain(t *testing.T) {
	const n = 10000
	gains := []float64{0.5, 1.0, 2.0}

	for _, gain := range gains {
		t.Run(floatStr(gain), func(t *testing.T) {
			state := NewDitherState(42)
			dst := make([]float64, n)

			GenerateTPDF(dst, gain, state)

			var maxAbs float64
			for _, v := range dst {
				a := math.Abs(v)
				if a > maxAbs {
					maxAbs = a
				}
			}

			// Max should scale with gain
			if maxAbs > gain*1.5 {
				t.Errorf("maxAbs = %v, exceeds expected range for gain %v", maxAbs, gain)
			}
			if maxAbs < gain*0.1 {
				t.Errorf("maxAbs = %v, too small for gain %v", maxAbs, gain)
			}
		})
	}
}

func TestDitherStateReproducibility(t *testing.T) {
	const n = 100

	state1 := NewDitherState(42)
	state2 := NewDitherState(42)

	dst1 := make([]float64, n)
	dst2 := make([]float64, n)

	GenerateTPDF(dst1, 1.0, state1)
	GenerateTPDF(dst2, 1.0, state2)

	for i := range dst1 {
		if dst1[i] != dst2[i] {
			t.Errorf("dst[%d]: state1 gave %v, state2 gave %v (same seed should give same output)", i, dst1[i], dst2[i])
			break
		}
	}
}

func TestDitherStateDifferentSeeds(t *testing.T) {
	const n = 100

	state1 := NewDitherState(42)
	state2 := NewDitherState(99)

	dst1 := make([]float64, n)
	dst2 := make([]float64, n)

	GenerateTPDF(dst1, 1.0, state1)
	GenerateTPDF(dst2, 1.0, state2)

	same := 0
	for i := range dst1 {
		if dst1[i] == dst2[i] {
			same++
		}
	}
	if same > n/2 {
		t.Errorf("different seeds produced %d/%d identical values", same, n)
	}
}

func TestGenerateTPDFZeroGain(t *testing.T) {
	const n = 100
	state := NewDitherState(42)
	dst := make([]float64, n)

	GenerateTPDF(dst, 0.0, state)

	for i, v := range dst {
		if v != 0 {
			t.Errorf("dst[%d] = %v, want 0 for zero gain", i, v)
			break
		}
	}
}
