package vecmath

import (
	"sync"

	"github.com/cwbudde/algo-vecmath/cpu"
	"github.com/cwbudde/algo-vecmath/internal/registry"
)

var (
	rotateDecayComplexF32Impl     func([]float32, []float32, []float32, []float32, []float32)
	rotateDecayAccumulateF32Impl  func([]float32, []float32, []float32, []float32, []float32, []float32, []float32)
	rotateDecayInitOnce           sync.Once
)

func initRotateDecayOperations() {
	features := cpu.DetectFeatures()

	entry := registry.Global.LookupFunc(features, func(e *registry.OpEntry) bool {
		return e.RotateDecayComplexF32 != nil
	})
	if entry == nil {
		panic("vecmath: no RotateDecayComplexF32 implementation registered")
	}
	rotateDecayComplexF32Impl = entry.RotateDecayComplexF32

	accEntry := registry.Global.LookupFunc(features, func(e *registry.OpEntry) bool {
		return e.RotateDecayAccumulateF32 != nil
	})
	if accEntry == nil {
		panic("vecmath: no RotateDecayAccumulateF32 implementation registered")
	}
	rotateDecayAccumulateF32Impl = accEntry.RotateDecayAccumulateF32
}

// RotateDecayComplexF32 rotates and damps a bank of complex oscillators in place.
//
// For each i:
//
//	re[i], im[i] = decay[i] * (re[i]*cosW[i] - im[i]*sinW[i]),
//	               decay[i] * (re[i]*sinW[i] + im[i]*cosW[i])
//
// All slices must have equal length. Panics if lengths differ.
//
// The implementation is automatically selected based on CPU features.
// After the first call, subsequent calls have zero dispatch overhead.
func RotateDecayComplexF32(re, im, cosW, sinW, decay []float32) {
	rotateDecayInitOnce.Do(initRotateDecayOperations)
	rotateDecayComplexF32Impl(re, im, cosW, sinW, decay)
}

// RotateDecayAccumulateF32 updates oscillator state and accumulates the weighted real part.
//
// For each i: re[i] and im[i] are rotated and decayed (see RotateDecayComplexF32),
// then dst[i] += gain[i] * re[i] (using the updated real part).
//
// All slices must have equal length. Panics if lengths differ.
//
// The implementation is automatically selected based on CPU features.
// After the first call, subsequent calls have zero dispatch overhead.
func RotateDecayAccumulateF32(dst []float32, re, im, cosW, sinW, decay, gain []float32) {
	rotateDecayInitOnce.Do(initRotateDecayOperations)
	rotateDecayAccumulateF32Impl(dst, re, im, cosW, sinW, decay, gain)
}
