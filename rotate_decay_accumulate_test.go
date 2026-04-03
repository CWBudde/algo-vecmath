package vecmath

import (
	"math"
	"testing"
)

// rotateDecayAccumulateF32Ref is the scalar reference for RotateDecayAccumulateF32.
func rotateDecayAccumulateF32Ref(dst []float32, re, im, cosW, sinW, decay, gain []float32) {
	for i := range re {
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

func TestRotateDecayAccumulateF32(t *testing.T) {
	for _, n := range rotateDecayBoundarySizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			dst := make([]float32, n)
			re := make([]float32, n)
			im := make([]float32, n)
			cosW := make([]float32, n)
			sinW := make([]float32, n)
			decay := make([]float32, n)
			gain := make([]float32, n)

			dstRef := make([]float32, n)
			reRef := make([]float32, n)
			imRef := make([]float32, n)

			for i := range n {
				dst[i] = float32(i) * 0.01
				re[i] = float32(i+1) * 0.1
				im[i] = float32(i+1) * 0.05
				freq := float64(i+1) * 0.01
				cosW[i] = float32(math.Cos(freq))
				sinW[i] = float32(math.Sin(freq))
				decay[i] = 0.999 - float32(i)*0.0001
				gain[i] = 0.5 + float32(i)*0.001

				dstRef[i] = dst[i]
				reRef[i] = re[i]
				imRef[i] = im[i]
			}

			rotateDecayAccumulateF32Ref(dstRef, reRef, imRef, cosW, sinW, decay, gain)
			RotateDecayAccumulateF32(dst, re, im, cosW, sinW, decay, gain)

			for i := range n {
				if !closeEnoughF32(re[i], reRef[i]) {
					t.Errorf("re[%d] = %v, want %v", i, re[i], reRef[i])
				}
				if !closeEnoughF32(im[i], imRef[i]) {
					t.Errorf("im[%d] = %v, want %v", i, im[i], imRef[i])
				}
				if !closeEnoughF32(dst[i], dstRef[i]) {
					t.Errorf("dst[%d] = %v, want %v", i, dst[i], dstRef[i])
				}
			}
		})
	}
}

func TestRotateDecayAccumulateF32_Accumulates(t *testing.T) {
	// Verify accumulation: dst should increase over multiple calls
	dst := []float32{0.0}
	re := []float32{1.0}
	im := []float32{0.0}
	cosW := []float32{1.0} // no rotation
	sinW := []float32{0.0}
	decay := []float32{1.0} // no decay
	gain := []float32{1.0}

	RotateDecayAccumulateF32(dst, re, im, cosW, sinW, decay, gain)
	if !closeEnoughF32(dst[0], 1.0) {
		t.Errorf("after 1 call: dst = %v, want 1.0", dst[0])
	}

	RotateDecayAccumulateF32(dst, re, im, cosW, sinW, decay, gain)
	if !closeEnoughF32(dst[0], 2.0) {
		t.Errorf("after 2 calls: dst = %v, want 2.0", dst[0])
	}
}

func TestRotateDecayAccumulateF32_EquivalentToSeparate(t *testing.T) {
	// Verify fused operation matches separate rotate + accumulate
	n := 32
	re1 := make([]float32, n)
	im1 := make([]float32, n)
	re2 := make([]float32, n)
	im2 := make([]float32, n)
	cosW := make([]float32, n)
	sinW := make([]float32, n)
	decay := make([]float32, n)
	gain := make([]float32, n)
	dst1 := make([]float32, n)
	dst2 := make([]float32, n)

	for i := range n {
		re1[i] = float32(i+1) * 0.1
		im1[i] = float32(i+1) * 0.05
		re2[i] = re1[i]
		im2[i] = im1[i]
		freq := float64(i+1) * 0.02
		cosW[i] = float32(math.Cos(freq))
		sinW[i] = float32(math.Sin(freq))
		decay[i] = 0.995
		gain[i] = 0.3 + float32(i)*0.01
	}

	// Fused path
	RotateDecayAccumulateF32(dst1, re1, im1, cosW, sinW, decay, gain)

	// Separate: rotate then accumulate
	RotateDecayComplexF32(re2, im2, cosW, sinW, decay)
	for i := range n {
		dst2[i] += gain[i] * re2[i]
	}

	for i := range n {
		if !closeEnoughF32(re1[i], re2[i]) {
			t.Errorf("re[%d] = %v, want %v", i, re1[i], re2[i])
		}
		if !closeEnoughF32(im1[i], im2[i]) {
			t.Errorf("im[%d] = %v, want %v", i, im1[i], im2[i])
		}
		if !closeEnoughF32(dst1[i], dst2[i]) {
			t.Errorf("dst[%d] = %v, want %v", i, dst1[i], dst2[i])
		}
	}
}

func TestRotateDecayAccumulateF32_Panics(t *testing.T) {
	tests := []struct {
		name  string
		dst   []float32
		re    []float32
		im    []float32
		cosW  []float32
		sinW  []float32
		decay []float32
		gain  []float32
	}{
		{"dst mismatch", make([]float32, 3), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4)},
		{"im mismatch", make([]float32, 4), make([]float32, 4), make([]float32, 3), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4)},
		{"gain mismatch", make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 4), make([]float32, 3)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r == nil {
					t.Error("expected panic, got none")
				}
			}()
			RotateDecayAccumulateF32(tt.dst, tt.re, tt.im, tt.cosW, tt.sinW, tt.decay, tt.gain)
		})
	}
}
