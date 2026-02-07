package vecmath

import "testing"

func BenchmarkGenerateTPDF(b *testing.B) {
	for _, tc := range benchSizes {
		b.Run(tc.name, func(b *testing.B) {
			dst := make([]float64, tc.size)
			state := NewDitherState(42)

			b.SetBytes(int64(tc.size * 8))
			b.ResetTimer()

			for i := 0; i < b.N; i++ {
				GenerateTPDF(dst, 1.0, state)
			}
		})
	}
}

func BenchmarkAddDitherTPDF(b *testing.B) {
	for _, tc := range benchSizes {
		b.Run(tc.name, func(b *testing.B) {
			dst := make([]float64, tc.size)
			for i := range dst {
				dst[i] = float64(i) * 0.001
			}
			state := NewDitherState(42)

			b.SetBytes(int64(tc.size * 8))
			b.ResetTimer()

			for i := 0; i < b.N; i++ {
				AddDitherTPDF(dst, 1.0, state)
			}
		})
	}
}
