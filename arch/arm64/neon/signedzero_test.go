//go:build arm64 && !purego

package neon

import (
	"math"
	"testing"
)

// The multiply kernels reconstruct `a * b` as `acc = -0.0; acc += a * b`,
// because VFMLA is the only vector floating-point arithmetic mnemonic the Go
// assembler accepts on arm64.  That identity has to be -0.0 and not +0.0:
// FMA rounds once, so -0.0 + (-0.0) is -0.0 and -0.0 + (+0.0) is +0.0, matching
// FMULD on both signs, whereas a +0.0 identity would turn every -0.0 product
// into +0.0.
//
// These tests are the guard for that choice.  They have to compare Signbit
// rather than values, because -0.0 == +0.0 is true in Go and an ordinary
// equality assertion would pass either way.

// signedZeroLengths spans the scalar tail (< 4), the vector body, and mixtures
// of the two, so a sign bug in one path cannot hide behind the other.
var signedZeroLengths = []int{1, 2, 3, 4, 5, 7, 8, 9, 16}

func checkSigns(t *testing.T, op string, got, want []float64) {
	t.Helper()

	for i := range want {
		if got[i] != want[i] || math.Signbit(got[i]) != math.Signbit(want[i]) {
			t.Errorf("%s[%d] = %v (signbit %v), want %v (signbit %v)",
				op, i, got[i], math.Signbit(got[i]), want[i], math.Signbit(want[i]))
		}
	}
}

func TestScaleBlockSignedZero_NEON(t *testing.T) {
	// Each pattern element is a value whose product with the scale is a zero
	// of one sign or the other.
	pattern := []float64{math.Copysign(0, -1), 0, -2, 2}
	scales := []float64{1, -1, 0, math.Copysign(0, -1)}

	for _, scale := range scales {
		for _, n := range signedZeroLengths {
			src := make([]float64, n)
			want := make([]float64, n)
			dst := make([]float64, n)

			for i := range src {
				src[i] = pattern[i%len(pattern)]
				want[i] = src[i] * scale // plain FMULD, the reference semantics
			}

			ScaleBlock(dst, src, scale)
			checkSigns(t, "ScaleBlock", dst, want)

			copy(dst, src)
			ScaleBlockInPlace(dst, scale)
			checkSigns(t, "ScaleBlockInPlace", dst, want)
		}
	}
}

func TestMulBlockSignedZero_NEON(t *testing.T) {
	negZero := math.Copysign(0, -1)

	aPattern := []float64{negZero, 0, negZero, 0, -2, 2, -2, 2}
	bPattern := []float64{1, 1, -1, -1, 0, 0, negZero, negZero}

	for _, n := range signedZeroLengths {
		a := make([]float64, n)
		b := make([]float64, n)
		want := make([]float64, n)
		dst := make([]float64, n)

		for i := range a {
			a[i] = aPattern[i%len(aPattern)]
			b[i] = bPattern[i%len(bPattern)]
			want[i] = a[i] * b[i]
		}

		MulBlock(dst, a, b)
		checkSigns(t, "MulBlock", dst, want)

		copy(dst, a)
		MulBlockInPlace(dst, b)
		checkSigns(t, "MulBlockInPlace", dst, want)
	}
}

// TestAddMulBlockSignedZero_NEON covers the two-stage kernel, where the add is
// reconstructed against a vector of ones and the multiply against -0.0.  The
// sum -0.0 + -0.0 is the only way to reach a negative zero out of the first
// stage, so it is the case that matters here.
func TestAddMulBlockSignedZero_NEON(t *testing.T) {
	negZero := math.Copysign(0, -1)

	aPattern := []float64{negZero, 0, negZero, -1}
	bPattern := []float64{negZero, negZero, 0, 1}

	for _, scale := range []float64{1, -1} {
		for _, n := range signedZeroLengths {
			a := make([]float64, n)
			b := make([]float64, n)
			want := make([]float64, n)
			dst := make([]float64, n)

			for i := range a {
				a[i] = aPattern[i%len(aPattern)]
				b[i] = bPattern[i%len(bPattern)]
				want[i] = (a[i] + b[i]) * scale
			}

			AddMulBlock(dst, a, b, scale)
			checkSigns(t, "AddMulBlock", dst, want)
		}
	}
}

// TestAddBlockSignedZero_NEON pins the add identity: -0.0 + -0.0 must stay
// -0.0, and x + 0.0*1.0 must not flip any sign.
func TestAddBlockSignedZero_NEON(t *testing.T) {
	negZero := math.Copysign(0, -1)

	aPattern := []float64{negZero, 0, negZero, 0}
	bPattern := []float64{negZero, negZero, 0, 0}

	for _, n := range signedZeroLengths {
		a := make([]float64, n)
		b := make([]float64, n)
		want := make([]float64, n)
		dst := make([]float64, n)

		for i := range a {
			a[i] = aPattern[i%len(aPattern)]
			b[i] = bPattern[i%len(bPattern)]
			want[i] = a[i] + b[i]
		}

		AddBlock(dst, a, b)
		checkSigns(t, "AddBlock", dst, want)

		copy(dst, a)
		AddBlockInPlace(dst, b)
		checkSigns(t, "AddBlockInPlace", dst, want)
	}
}
