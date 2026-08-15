package vecmath

import (
	"math"
	"testing"
)

// Reference implementation for AXPY testing.
func addScaledBlockInPlaceRef(dst, src []float64, scale float64) {
	for i := range dst {
		dst[i] += src[i] * scale
	}
}

func TestAddScaledBlockInPlace(t *testing.T) {
	sizes := []int{0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 100, 1000}
	scales := []float64{0.0, 1.0, -1.0, 0.5, 2.0, math.Pi}

	for _, n := range sizes {
		for _, scale := range scales {
			t.Run(sizeStr(n)+"_scale_"+floatStr(scale), func(t *testing.T) {
				src := make([]float64, n)
				dst := make([]float64, n)
				expected := make([]float64, n)

				for i := 0; i < n; i++ {
					src[i] = float64(i) + 0.5
					dst[i] = float64(n-i) - 0.25
					expected[i] = dst[i]
				}

				addScaledBlockInPlaceRef(expected, src, scale)
				AddScaledBlockInPlace(dst, src, scale)

				for i := 0; i < n; i++ {
					if !closeEnough(dst[i], expected[i]) {
						t.Errorf("AddScaledBlockInPlace[%d]: got %v, want %v", i, dst[i], expected[i])
					}
				}
			})
		}
	}
}

// TestAddScaledBlockInPlaceMatchesScaleThenAdd pins the identity that makes
// this kernel a drop-in for the two-pass idiom it replaces.
func TestAddScaledBlockInPlaceMatchesScaleThenAdd(t *testing.T) {
	const n = 257

	src := make([]float64, n)
	fused := make([]float64, n)
	twoPass := make([]float64, n)
	tmp := make([]float64, n)

	for i := 0; i < n; i++ {
		src[i] = math.Sin(float64(i)) * 1e3
		fused[i] = math.Cos(float64(i)) * 1e-3
		twoPass[i] = fused[i]
	}

	const scale = -0.37

	AddScaledBlockInPlace(fused, src, scale)
	ScaleBlock(tmp, src, scale)
	AddBlockInPlace(twoPass, tmp)

	for i := 0; i < n; i++ {
		if !closeEnough(fused[i], twoPass[i]) {
			t.Errorf("index %d: fused = %v, two-pass = %v", i, fused[i], twoPass[i])
		}
	}
}

func TestAddScaledBlockInPlaceLengthMismatch(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Error("expected panic on length mismatch")
		}
	}()

	AddScaledBlockInPlace(make([]float64, 4), make([]float64, 5), 1)
}
