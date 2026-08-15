package vecmath

import "testing"

func BenchmarkAddScaledBlockInPlace(b *testing.B) {
	for _, tc := range benchSizes {
		b.Run(tc.name, func(b *testing.B) {
			src := make([]float64, tc.size)
			dst := make([]float64, tc.size)
			scale := 1.5

			for i := range src {
				src[i] = float64(i) + 0.5
			}

			b.SetBytes(int64(tc.size * 8 * 3))
			b.ResetTimer()

			for i := 0; i < b.N; i++ {
				AddScaledBlockInPlace(dst, src, scale)
			}
		})
	}
}

func BenchmarkAddScaledBlockInPlaceRef(b *testing.B) {
	for _, tc := range benchSizes {
		b.Run(tc.name, func(b *testing.B) {
			src := make([]float64, tc.size)
			dst := make([]float64, tc.size)
			scale := 1.5

			for i := range src {
				src[i] = float64(i) + 0.5
			}

			b.SetBytes(int64(tc.size * 8 * 3))
			b.ResetTimer()

			for i := 0; i < b.N; i++ {
				addScaledBlockInPlaceRef(dst, src, scale)
			}
		})
	}
}

// BenchmarkAddScaledBlockInPlaceTwoPass measures the idiom this kernel
// replaces: ScaleBlock into a temporary, then AddBlockInPlace.  Both SIMD,
// both from this package -- the difference is purely the extra pass over
// memory and the temporary buffer.
func BenchmarkAddScaledBlockInPlaceTwoPass(b *testing.B) {
	for _, tc := range benchSizes {
		b.Run(tc.name, func(b *testing.B) {
			src := make([]float64, tc.size)
			dst := make([]float64, tc.size)
			tmp := make([]float64, tc.size)
			scale := 1.5

			for i := range src {
				src[i] = float64(i) + 0.5
			}

			b.SetBytes(int64(tc.size * 8 * 3))
			b.ResetTimer()

			for i := 0; i < b.N; i++ {
				ScaleBlock(tmp, src, scale)
				AddBlockInPlace(dst, tmp)
			}
		})
	}
}
