//go:build !purego && arm64

#include "textflag.h"

// Multiplicative identity, used only to collapse the accumulators at the end:
// VFMLA is the only vector floating-point arithmetic mnemonic the Go assembler
// accepts on arm64, so folding acc0 += acc1 goes through a multiply by 1.0.
DATA ·dotOne<>(SB)/8, $0x3ff0000000000000
DATA ·dotOne<>+8(SB)/8, $0x3ff0000000000000
GLOBL ·dotOne<>(SB), RODATA, $16

// func dotProductNEON(a, b []float64) float64
//
// Four vector accumulators, two lanes each, so eight independent multiply-
// accumulate chains are in flight to cover FMA latency.  The previous revision
// used two *scalar* FMADDD accumulators, which is where the measured 3.3x
// shortfall against the AVX2 kernel came from.
//
// Short inputs take the two-accumulator scalar path instead; see the comment
// in sum.s for why.  This one matters in practice, because dsp/filter/fir
// calls DotProduct once per output sample with as few as 32 taps.
//
// The threshold is measured, forcing each path over a size sweep on an Apple
// M5 (ns/op, best of 3):
//
//	     n:    16    32    48    64    96   128   192   256   512
//	scalar:     3     5     7     9    15    23    40    63   134
//	vector:     7     8    10    12    16    19    26    33    62
//
// so the two cross at 128.
TEXT ·dotProductNEON(SB), NOSPLIT, $0-56
	MOVD a_base+0(FP), R0
	MOVD b_base+24(FP), R1
	MOVD a_len+8(FP), R2

	CMP $128, R2
	BLT dot_small

	MOVD $·dotOne<>(SB), R6
	VLD1 (R6), [V30.D2]       // V30 = {1.0, 1.0}

	VEOR V0.B16, V0.B16, V0.B16
	VEOR V1.B16, V1.B16, V1.B16
	VEOR V2.B16, V2.B16, V2.B16
	VEOR V3.B16, V3.B16, V3.B16

	// R4 = len / 8 (octets), R5 = len % 8 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $3, R2, R4
	AND $7, R2, R5

dot_octet_loop:
	VLD1.P 64(R0), [V4.D2, V5.D2, V6.D2, V7.D2]      // a[i..i+7]
	VLD1.P 64(R1), [V8.D2, V9.D2, V10.D2, V11.D2]    // b[i..i+7]
	VFMLA  V8.D2, V4.D2, V0.D2                       // acc += a * b
	VFMLA  V9.D2, V5.D2, V1.D2
	VFMLA  V10.D2, V6.D2, V2.D2
	VFMLA  V11.D2, V7.D2, V3.D2

	SUBS $1, R4
	BNE  dot_octet_loop

	// Collapse the four accumulators pairwise, then the two lanes.  The lane
	// collapse moves lane 1 of V0 into lane 0 of V1 directly, so that F0 and
	// F1 -- which alias the low halves of V0 and V1 -- hold the two values
	// without a round trip through general registers.  V1 is dead by this
	// point, having already been folded into V0.
	VFMLA V30.D2, V1.D2, V0.D2
	VFMLA V30.D2, V3.D2, V2.D2
	VFMLA V30.D2, V2.D2, V0.D2

	VMOV  V0.D[1], V1.D[0]
	FADDD F1, F0, F0

	CBZ R5, dot_done

dot_scalar:
	FMOVD  (R0), F2
	FMOVD  (R1), F3
	FMADDD F3, F0, F2, F0     // F0 = F0 + F2*F3

	ADD  $8, R0
	ADD  $8, R1
	SUBS $1, R5
	BNE  dot_scalar

dot_done:
	FMOVD F0, ret+48(FP)
	RET

	// Two independent scalar accumulators over FLDPD pairs, enough to break
	// the FMADDD dependency chain without any vector setup to amortise.
dot_small:
	FMOVD $0.0, F0
	FMOVD $0.0, F1

	// R4 = len / 2 (pairs), R5 = len % 2 (tail).  Both must be computed
	// before any branch that skips the pair loop.
	LSR  $1, R2, R4
	ANDS $1, R2, R5
	CBZ  R4, dot_small_combine

dot_small_pair:
	FLDPD  (R0), (F2, F3)     // a[i], a[i+1]
	FLDPD  (R1), (F4, F5)     // b[i], b[i+1]
	FMADDD F4, F0, F2, F0     // F0 += a[i]   * b[i]
	FMADDD F5, F1, F3, F1     // F1 += a[i+1] * b[i+1]

	ADD  $16, R0
	ADD  $16, R1
	SUBS $1, R4
	BNE  dot_small_pair

dot_small_combine:
	FADDD F1, F0, F0
	CBZ   R5, dot_small_done

	FMOVD  (R0), F2
	FMOVD  (R1), F3
	FMADDD F3, F0, F2, F0

dot_small_done:
	FMOVD F0, ret+48(FP)
	RET
