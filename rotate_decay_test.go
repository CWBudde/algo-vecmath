package vecmath

import (
	"math"
	"testing"
)

// rotateDecayComplexF32Ref is the scalar reference for RotateDecayComplexF32.
func rotateDecayComplexF32Ref(re, im, cosW, sinW, decay []float32) {
	for i := range re {
		r := re[i]
		m := im[i]
		c := cosW[i]
		s := sinW[i]
		d := decay[i]
		re[i] = d * (r*c - m*s)
		im[i] = d * (r*s + m*c)
	}
}

// closeEnoughF32 checks if two float32 values are approximately equal.
func closeEnoughF32(a, b float32) bool {
	const epsilon = 1e-6
	if a == b {
		return true
	}
	diff := float64(a) - float64(b)
	if diff < 0 {
		diff = -diff
	}
	if a == 0 || b == 0 {
		return diff < epsilon
	}
	absA := math.Abs(float64(a))
	absB := math.Abs(float64(b))
	max := absA
	if absB > max {
		max = absB
	}
	return diff/max < epsilon
}

var rotateDecayBoundarySizes = []int{0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 100, 1000}

func TestRotateDecayComplexF32(t *testing.T) {
	for _, n := range rotateDecayBoundarySizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			re := make([]float32, n)
			im := make([]float32, n)
			cosW := make([]float32, n)
			sinW := make([]float32, n)
			decay := make([]float32, n)

			reRef := make([]float32, n)
			imRef := make([]float32, n)

			for i := range n {
				// Use deterministic but varied values
				re[i] = float32(i+1) * 0.1
				im[i] = float32(i+1) * 0.05
				freq := float64(i+1) * 0.01
				cosW[i] = float32(math.Cos(freq))
				sinW[i] = float32(math.Sin(freq))
				decay[i] = 0.999 - float32(i)*0.0001

				reRef[i] = re[i]
				imRef[i] = im[i]
			}

			rotateDecayComplexF32Ref(reRef, imRef, cosW, sinW, decay)
			RotateDecayComplexF32(re, im, cosW, sinW, decay)

			for i := range n {
				if !closeEnoughF32(re[i], reRef[i]) {
					t.Errorf("re[%d] = %v, want %v", i, re[i], reRef[i])
				}
				if !closeEnoughF32(im[i], imRef[i]) {
					t.Errorf("im[%d] = %v, want %v", i, im[i], imRef[i])
				}
			}
		})
	}
}

func TestRotateDecayComplexF32_UnitCircle(t *testing.T) {
	// A single oscillator at frequency pi/4 with no decay should trace the unit circle
	re := []float32{1.0}
	im := []float32{0.0}
	cosW := []float32{float32(math.Cos(math.Pi / 4))}
	sinW := []float32{float32(math.Sin(math.Pi / 4))}
	decay := []float32{1.0}

	// After 8 rotations of pi/4, we should be back near the start
	for range 8 {
		RotateDecayComplexF32(re, im, cosW, sinW, decay)
	}

	if !closeEnoughF32(re[0], 1.0) {
		t.Errorf("after full rotation: re = %v, want ~1.0", re[0])
	}
	if !closeEnoughF32(im[0], 0.0) {
		t.Errorf("after full rotation: im = %v, want ~0.0", im[0])
	}
}

func TestRotateDecayComplexF32_Decay(t *testing.T) {
	// Verify that decay reduces magnitude over time
	re := []float32{1.0}
	im := []float32{0.0}
	cosW := []float32{1.0} // no rotation
	sinW := []float32{0.0}
	decay := []float32{0.5}

	RotateDecayComplexF32(re, im, cosW, sinW, decay)

	if !closeEnoughF32(re[0], 0.5) {
		t.Errorf("re = %v, want 0.5", re[0])
	}

	RotateDecayComplexF32(re, im, cosW, sinW, decay)

	if !closeEnoughF32(re[0], 0.25) {
		t.Errorf("re = %v, want 0.25", re[0])
	}
}

func TestRotateDecayComplexF32_Panics(t *testing.T) {
	tests := []struct {
		name  string
		re    []float32
		im    []float32
		cosW  []float32
		sinW  []float32
		decay []float32
	}{
		{"im mismatch", make([]float32, 4), make([]float32, 3), make([]float32, 4), make([]float32, 4), make([]float32, 4)},
		{"cosW mismatch", make([]float32, 4), make([]float32, 4), make([]float32, 3), make([]float32, 4), make([]float32, 4)},
		{"sinW mismatch", make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 3), make([]float32, 4)},
		{"decay mismatch", make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 3)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r == nil {
					t.Error("expected panic, got none")
				}
			}()
			RotateDecayComplexF32(tt.re, tt.im, tt.cosW, tt.sinW, tt.decay)
		})
	}
}
