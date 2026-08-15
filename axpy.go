package vecmath

import (
	"sync"

	"github.com/cwbudde/algo-vecmath/cpu"
	"github.com/cwbudde/algo-vecmath/internal/registry"
)

var (
	addScaledBlockInPlaceImpl func([]float64, []float64, float64)
	axpyInitOnce              sync.Once
)

func initAXPYOperations() {
	features := cpu.DetectFeatures()

	entry := registry.Global.LookupFunc(features, func(e *registry.OpEntry) bool {
		return e.AddScaledBlockInPlace != nil
	})
	if entry == nil {
		panic("vecmath: no AddScaledBlockInPlace implementation registered")
	}

	addScaledBlockInPlaceImpl = entry.AddScaledBlockInPlace
}

// AddScaledBlockInPlace accumulates a scaled block: dst[i] += src[i] * scalar.
//
// This is the AXPY primitive.  It replaces the common two-pass idiom
//
//	ScaleBlock(tmp, src, scalar)
//	AddBlockInPlace(dst, tmp)
//
// with a single pass, dropping the temporary buffer and one traversal of
// memory.  Slices must have equal length; panics if lengths differ.
//
// The implementation is automatically selected based on CPU features.
// After the first call, subsequent calls have zero dispatch overhead.
func AddScaledBlockInPlace(dst, src []float64, scalar float64) {
	axpyInitOnce.Do(initAXPYOperations)
	addScaledBlockInPlaceImpl(dst, src, scalar)
}
