//go:build !purego && arm64

#include "textflag.h"

// Identity vectors for reconstructing plain add and multiply out of VFMLA.
// See the comment in scale.s for why the additive identity must be -0.0.
DATA ·fusedOne<>(SB)/8, $0x3ff0000000000000
DATA ·fusedOne<>+8(SB)/8, $0x3ff0000000000000
GLOBL ·fusedOne<>(SB), RODATA, $16

DATA ·fusedNegZero<>(SB)/8, $0x8000000000000000
DATA ·fusedNegZero<>+8(SB)/8, $0x8000000000000000
GLOBL ·fusedNegZero<>(SB), RODATA, $16

// func addMulBlockNEON(dst, a, b []float64, scale float64)
// Fused add-multiply: dst[i] = (a[i] + b[i]) * scale
//
// Two VFMLA stages per accumulator: the first reconstructs a+b against a vector
// of ones (exact, so identical to FADDD), the second the multiply by scale
// against -0.0 (exact, so identical to FMULD).  Bit-identical to the scalar
// tail below and to the generic Go implementation.
TEXT ·addMulBlockNEON(SB), NOSPLIT, $0-80
	MOVD  dst_base+0(FP), R0
	MOVD  a_base+24(FP), R1
	MOVD  b_base+48(FP), R2
	MOVD  dst_len+8(FP), R3
	MOVD  scale+72(FP), R7     // scale bits, for the vector broadcast
	FMOVD scale+72(FP), F3     // scale, for the scalar tail
	                           // F3 deliberately, not F4: F4 aliases the low
	                           // half of V4, which the vector loop overwrites.

	VDUP R7, V2.D2             // V2 = {scale, scale}

	MOVD $·fusedOne<>(SB), R6
	VLD1 (R6), [V30.D2]        // V30 = {1.0, 1.0}
	MOVD $·fusedNegZero<>(SB), R9
	VLD1 (R9), [V31.D2]        // V31 = {-0.0, -0.0}

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, addmul_tail

addmul_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // a[i..i+3]
	VLD1.P 32(R2), [V6.D2, V7.D2]    // b[i..i+3], seeds the sum
	VFMLA  V30.D2, V4.D2, V6.D2      // t = b + a * 1.0
	VFMLA  V30.D2, V5.D2, V7.D2

	VORR  V31.B16, V31.B16, V8.B16   // seed accumulators with -0.0
	VORR  V31.B16, V31.B16, V9.B16
	VFMLA V2.D2, V6.D2, V8.D2        // acc = -0.0 + t * scale
	VFMLA V2.D2, V7.D2, V9.D2

	VST1.P [V8.D2, V9.D2], 32(R0)

	SUBS $1, R4
	BNE  addmul_quad_loop

addmul_tail:
	CBZ R5, addmul_done

addmul_scalar:
	FMOVD (R1), F0
	FMOVD (R2), F1
	FADDD F1, F0, F0
	FMULD F3, F0, F0
	FMOVD F0, (R0)

	ADD  $8, R1
	ADD  $8, R2
	ADD  $8, R0
	SUBS $1, R5
	BNE  addmul_scalar

addmul_done:
	RET

// func mulAddBlockNEON(dst, a, b, c []float64)
// Fused multiply-add: dst[i] = a[i] * b[i] + c[i]
//
// c is loaded straight into the accumulators, so the whole operation is a
// single VFMLA per register pair -- this is exactly the instruction VFMLA
// computes.
//
// Note this is a genuine multiply-accumulate with one rounding, where the
// previous revision of this kernel used a separate FMULD and FADDD.  The fused
// form is the correct one: the generic Go implementation writes
// `a[i]*b[i] + c[i]`, which the compiler contracts into FMADDD on arm64, so the
// unfused assembly was the odd one out and could disagree with the reference by
// an ulp.  The scalar tail below uses FMADDD for the same reason.
TEXT ·mulAddBlockNEON(SB), NOSPLIT, $0-96
	MOVD dst_base+0(FP), R0
	MOVD a_base+24(FP), R1
	MOVD b_base+48(FP), R2
	MOVD c_base+72(FP), R8
	MOVD dst_len+8(FP), R3

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, muladd_tail

muladd_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // a[i..i+3]
	VLD1.P 32(R2), [V6.D2, V7.D2]    // b[i..i+3]
	VLD1.P 32(R8), [V8.D2, V9.D2]    // c[i..i+3], seeds the accumulators
	VFMLA  V6.D2, V4.D2, V8.D2       // acc = c + a * b
	VFMLA  V7.D2, V5.D2, V9.D2
	VST1.P [V8.D2, V9.D2], 32(R0)

	SUBS $1, R4
	BNE  muladd_quad_loop

muladd_tail:
	CBZ R5, muladd_done

muladd_scalar:
	FMOVD  (R1), F0
	FMOVD  (R2), F1
	FMOVD  (R8), F2
	FMADDD F1, F2, F0, F0     // F0 = F2 + F0*F1
	FMOVD  F0, (R0)

	ADD  $8, R1
	ADD  $8, R2
	ADD  $8, R8
	ADD  $8, R0
	SUBS $1, R5
	BNE  muladd_scalar

muladd_done:
	RET
