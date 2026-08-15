//go:build arm64 && !purego

package neon

import (
	"math"
	"testing"
)

// fmaLengths spans the scalar tail and the vector body of the unroll-4 kernels.
var fmaLengths = []int{0, 1, 2, 3, 4, 5, 7, 8, 9, 16, 17, 64, 100}

// TestMulAddBlockIsFused_NEON pins down that MulAddBlock rounds once.
//
// This kernel used to issue a separate FMULD and FADDD.  That was wrong: the
// generic Go implementation writes `a[i]*b[i] + c[i]`, which the compiler
// contracts into FMADDD on arm64, so the unfused assembly disagreed with its
// own reference implementation.  The inputs below are chosen so the two
// roundings give visibly different answers rather than differing by an ulp:
// the exact product is 1 - 2^-104, so an unfused multiply rounds it to exactly
// 1.0 and the subsequent add cancels to zero, while a fused operation keeps the
// low bits and returns -2^-104.
func TestMulAddBlockIsFused_NEON(t *testing.T) {
	const eps = 1.0 / (1 << 52)

	a := 1 + eps
	b := 1 - eps
	c := -1.0

	want := math.FMA(a, b, c)

	if want == 0 {
		t.Fatal("test inputs do not distinguish fused from unfused arithmetic")
	}

	for _, n := range fmaLengths {
		if n == 0 {
			continue
		}

		as := make([]float64, n)
		bs := make([]float64, n)
		cs := make([]float64, n)
		dst := make([]float64, n)

		for i := range as {
			as[i], bs[i], cs[i] = a, b, c
		}

		MulAddBlock(dst, as, bs, cs)

		for i := range dst {
			if dst[i] != want {
				t.Errorf("MulAddBlock(len=%d)[%d] = %v, want %v (unfused would give %v)",
					n, i, dst[i], want, a*b+c)
			}
		}
	}
}

// TestAddScaledBlockInPlace_NEON exercises the AXPY kernel over the same length
// sweep as the rest of the backend.  It had no package-local test.
func TestAddScaledBlockInPlace_NEON(t *testing.T) {
	scales := []float64{0, 1, -1, 2.5}

	for _, scale := range scales {
		for _, n := range fmaLengths {
			dst := make([]float64, n)
			src := make([]float64, n)
			want := make([]float64, n)

			for i := range dst {
				dst[i] = float64(i%11) - 5.0
				src[i] = float64(i%7) + 1.0
				// The kernel fuses, so the reference must fuse too.
				want[i] = math.FMA(src[i], scale, dst[i])
			}

			AddScaledBlockInPlace(dst, src, scale)

			for i := range dst {
				if dst[i] != want[i] {
					t.Errorf("AddScaledBlockInPlace(len=%d, scale=%v)[%d] = %v, want %v",
						n, scale, i, dst[i], want[i])
				}
			}
		}
	}
}

// TestAddScaledBlockInPlaceIsFused_NEON is the AXPY counterpart of the
// MulAddBlock test above: dst + src*scale must round once.
func TestAddScaledBlockInPlaceIsFused_NEON(t *testing.T) {
	const eps = 1.0 / (1 << 52)

	src := 1 + eps
	scale := 1 - eps
	base := -1.0

	want := math.FMA(src, scale, base)

	if want == 0 {
		t.Fatal("test inputs do not distinguish fused from unfused arithmetic")
	}

	for _, n := range fmaLengths {
		if n == 0 {
			continue
		}

		dst := make([]float64, n)
		srcs := make([]float64, n)

		for i := range dst {
			dst[i] = base
			srcs[i] = src
		}

		AddScaledBlockInPlace(dst, srcs, scale)

		for i := range dst {
			if dst[i] != want {
				t.Errorf("AddScaledBlockInPlace(len=%d)[%d] = %v, want %v (unfused would give %v)",
					n, i, dst[i], want, base+src*scale)
			}
		}
	}
}
