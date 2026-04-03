package vecmath

import (
	"math"
	"testing"
)

// Modal synthesis benchmark sizes: typical partial counts and block sizes
var modalBenchSizes = []struct {
	name string
	size int
}{
	{"8", 8},
	{"16", 16},
	{"24", 24},
	{"32", 32},
	{"64", 64},
	{"128", 128},
	{"256", 256},
}

func makeModalBenchData(n int) (re, im, cosW, sinW, decay, gain []float32) {
	re = make([]float32, n)
	im = make([]float32, n)
	cosW = make([]float32, n)
	sinW = make([]float32, n)
	decay = make([]float32, n)
	gain = make([]float32, n)

	for i := range n {
		re[i] = float32(i+1) * 0.01
		im[i] = float32(i+1) * 0.005
		freq := float64(i+1) * 0.02
		cosW[i] = float32(math.Cos(freq))
		sinW[i] = float32(math.Sin(freq))
		decay[i] = 0.9999
		gain[i] = 1.0 / float32(n)
	}
	return
}

func BenchmarkRotateDecayComplexF32(b *testing.B) {
	for _, sz := range modalBenchSizes {
		re, im, cosW, sinW, decay, _ := makeModalBenchData(sz.size)
		b.Run(sz.name, func(b *testing.B) {
			b.SetBytes(int64(sz.size) * 4 * 5) // 5 float32 slices read/written
			for b.Loop() {
				RotateDecayComplexF32(re, im, cosW, sinW, decay)
			}
		})
	}
}

func BenchmarkRotateDecayAccumulateF32(b *testing.B) {
	for _, sz := range modalBenchSizes {
		re, im, cosW, sinW, decay, gain := makeModalBenchData(sz.size)
		dst := make([]float32, sz.size)
		b.Run(sz.name, func(b *testing.B) {
			b.SetBytes(int64(sz.size) * 4 * 7) // 7 float32 slices
			for b.Loop() {
				RotateDecayAccumulateF32(dst, re, im, cosW, sinW, decay, gain)
			}
		})
	}
}
