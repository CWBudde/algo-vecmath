//go:build arm64 && !purego

package neon

import (
	"math"
	"testing"
)

// reductionSizes deliberately straddles the unroll-8 boundary of the reduction
// kernels (and the unroll-4 boundary of the elementwise ones) from every side,
// because the tail counter is exactly where this backend has gone wrong before:
// commit 3c3de3b fixed an uninitialised tail counter that wrote out of bounds
// for len == 1.
var reductionSizes = []int{
	0, 1, 2, 3, 4, 5, 6, 7,
	8, 9, 10, 15, 16, 17, 23, 24, 25,
	31, 32, 33, 63, 64, 65, 100, 1000,
}

// TestSum_NEON checks the kernel on values that are exactly representable, so
// that the eight-way accumulation order the kernel uses and the sequential
// order of the reference cannot disagree.  Any difference is then a real bug,
// not reassociation, and can be asserted exactly.
func TestSum_NEON(t *testing.T) {
	for _, n := range reductionSizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			x := make([]float64, n)

			var want float64

			for i := range x {
				x[i] = float64(i%17) - 8.0 // small integers: exact
				want += x[i]
			}

			if got := Sum(x); got != want {
				t.Errorf("Sum(len=%d) = %v, want %v", n, got, want)
			}
		})
	}
}

// TestSumReassociation_NEON uses values that are not exactly representable, so
// the kernel's accumulation order genuinely differs from a sequential sum.
// Compared against a Kahan-compensated reference, which is more accurate than
// either, with a relative tolerance.
func TestSumReassociation_NEON(t *testing.T) {
	for _, n := range reductionSizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			x := make([]float64, n)
			for i := range x {
				x[i] = math.Sin(float64(i)) * 1e3
			}

			want := kahanSum(x)

			got := Sum(x)
			if !closeEnough(got, want) {
				t.Errorf("Sum(len=%d) = %v, want ~%v", n, got, want)
			}
		})
	}
}

func TestDotProduct_NEON(t *testing.T) {
	for _, n := range reductionSizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			a := make([]float64, n)
			b := make([]float64, n)

			var want float64

			for i := range a {
				a[i] = float64(i%13) - 6.0 // exact
				b[i] = float64(i%7) + 1.0  // exact
				want += a[i] * b[i]        // products and sum stay exact
			}

			if got := DotProduct(a, b); got != want {
				t.Errorf("DotProduct(len=%d) = %v, want %v", n, got, want)
			}
		})
	}
}

func TestDotProductReassociation_NEON(t *testing.T) {
	for _, n := range reductionSizes {
		t.Run(sizeStr(n), func(t *testing.T) {
			a := make([]float64, n)
			b := make([]float64, n)
			products := make([]float64, n)

			for i := range a {
				a[i] = math.Sin(float64(i)) * 1e2
				b[i] = math.Cos(float64(i)) * 1e2
				// The kernel fuses the multiply into the accumulation, so the
				// reference must fuse it too or the two disagree by more than
				// the reassociation alone.
				products[i] = math.FMA(a[i], b[i], 0)
			}

			want := kahanSum(products)

			got := DotProduct(a, b)
			if !closeEnough(got, want) {
				t.Errorf("DotProduct(len=%d) = %v, want ~%v", n, got, want)
			}
		})
	}
}

// TestSumInfNaN_NEON pins down the behaviour of the special values, which the
// multiply-by-one accumulation must not disturb: Inf*1.0 is Inf, NaN*1.0 is NaN.
func TestSumInfNaN_NEON(t *testing.T) {
	tests := []struct {
		name string
		in   []float64
		want func(float64) bool
	}{
		{"positive inf", []float64{1, math.Inf(1), 2}, func(v float64) bool { return math.IsInf(v, 1) }},
		{"negative inf", []float64{1, math.Inf(-1), 2}, func(v float64) bool { return math.IsInf(v, -1) }},
		{"nan", []float64{1, math.NaN(), 2}, math.IsNaN},
		{"inf cancellation", []float64{math.Inf(1), math.Inf(-1)}, math.IsNaN},
		// Long enough to land in the vector loop rather than the scalar tail.
		{"nan in vector body", append(make([]float64, 16), math.NaN()), math.IsNaN},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Sum(tt.in); !tt.want(got) {
				t.Errorf("Sum(%v) = %v, which is not the expected special value", tt.in, got)
			}
		})
	}
}

func kahanSum(x []float64) float64 {
	var sum, c float64

	for _, v := range x {
		y := v - c
		t := sum + y
		c = (t - sum) - y
		sum = t
	}

	return sum
}

func closeEnough(got, want float64) bool {
	if got == want {
		return true
	}

	scale := math.Max(math.Abs(want), 1)

	return math.Abs(got-want) <= 1e-12*scale
}
