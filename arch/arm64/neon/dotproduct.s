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
TEXT ·dotProductNEON(SB), NOSPLIT, $0-56
	MOVD a_base+0(FP), R0
	MOVD b_base+24(FP), R1
	MOVD a_len+8(FP), R2

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
	CBZ R4, dot_fold

dot_octet_loop:
	VLD1.P 64(R0), [V4.D2, V5.D2, V6.D2, V7.D2]      // a[i..i+7]
	VLD1.P 64(R1), [V8.D2, V9.D2, V10.D2, V11.D2]    // b[i..i+7]
	VFMLA  V8.D2, V4.D2, V0.D2                       // acc += a * b
	VFMLA  V9.D2, V5.D2, V1.D2
	VFMLA  V10.D2, V6.D2, V2.D2
	VFMLA  V11.D2, V7.D2, V3.D2

	SUBS $1, R4
	BNE  dot_octet_loop

dot_fold:
	// Collapse the four accumulators pairwise, then the two lanes.
	VFMLA V30.D2, V1.D2, V0.D2
	VFMLA V30.D2, V3.D2, V2.D2
	VFMLA V30.D2, V2.D2, V0.D2

	// Both lanes must reach general registers before either is moved into an
	// F register.  F0 aliases the low half of V0, and a scalar FP write zeroes
	// the upper half of its V register -- so writing F0 first would destroy
	// lane 1 before it could be read.
	VMOV  V0.D[0], R10
	VMOV  V0.D[1], R11
	FMOVD R10, F0
	FMOVD R11, F1
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
