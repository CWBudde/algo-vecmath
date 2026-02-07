package vecmath

import (
	"sync"

	"github.com/cwbudde/algo-vecmath/cpu"
	"github.com/cwbudde/algo-vecmath/internal/registry"
)

var (
	maxAbsImpl     func([]float64) float64
	maxAbsInitOnce sync.Once
)

func initMaxAbsOperation() {
	features := cpu.DetectFeatures()
	entry := registry.Global.Lookup(features)
	if entry == nil {
		panic("vecmath: no maxabs implementation registered")
	}
	if entry.MaxAbs == nil {
		panic("vecmath: selected implementation missing maxabs operation")
	}
	maxAbsImpl = entry.MaxAbs
}

func MaxAbs(x []float64) float64 {
	maxAbsInitOnce.Do(initMaxAbsOperation)
	return maxAbsImpl(x)
}
