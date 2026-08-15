//go:build !purego && arm64

#include "textflag.h"

// Additive identity for reconstructing a plain multiply out of VFMLA.  See the
// comment in scale.s for why this must be -0.0 rather than +0.0.
DATA ·mulNegZero<>(SB)/8, $0x8000000000000000
DATA ·mulNegZero<>+8(SB)/8, $0x8000000000000000
GLOBL ·mulNegZero<>(SB), RODATA, $16

// func mulBlockNEON(dst, a, b []float64)
// Element-wise multiply: dst[i] = a[i] * b[i]
//
// Four float64 per iteration in two V registers.
TEXT ·mulBlockNEON(SB), NOSPLIT, $0-72
	MOVD dst_base+0(FP), R0   // dst.data
	MOVD a_base+24(FP), R1    // a.data
	MOVD b_base+48(FP), R2    // b.data
	MOVD dst_len+8(FP), R3    // len(dst)

	MOVD $·mulNegZero<>(SB), R6
	VLD1 (R6), [V31.D2]       // V31 = {-0.0, -0.0}

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, mulblock_tail

mulblock_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // a[i..i+3]
	VLD1.P 32(R2), [V8.D2, V9.D2]    // b[i..i+3]
	VORR   V31.B16, V31.B16, V6.B16  // seed accumulators with -0.0
	VORR   V31.B16, V31.B16, V7.B16
	VFMLA  V8.D2, V4.D2, V6.D2       // acc = -0.0 + a * b
	VFMLA  V9.D2, V5.D2, V7.D2
	VST1.P [V6.D2, V7.D2], 32(R0)

	SUBS $1, R4
	BNE  mulblock_quad_loop

mulblock_tail:
	CBZ R5, mulblock_done

mulblock_scalar:
	FMOVD (R1), F0            // Load from a
	FMOVD (R2), F1            // Load from b
	FMULD F1, F0, F0          // F0 = a * b
	FMOVD F0, (R0)            // Store to dst

	ADD  $8, R1
	ADD  $8, R2
	ADD  $8, R0
	SUBS $1, R5
	BNE  mulblock_scalar

mulblock_done:
	RET

// func mulBlockInPlaceNEON(dst, src []float64)
// In-place multiply: dst[i] *= src[i]
TEXT ·mulBlockInPlaceNEON(SB), NOSPLIT, $0-48
	MOVD dst_base+0(FP), R0   // dst.data
	MOVD src_base+24(FP), R1  // src.data
	MOVD dst_len+8(FP), R3    // len(dst)

	MOVD $·mulNegZero<>(SB), R6
	VLD1 (R6), [V31.D2]

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, mulinplace_tail

mulinplace_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // src[i..i+3]
	VLD1   (R0), [V8.D2, V9.D2]      // dst[i..i+3]
	VORR   V31.B16, V31.B16, V6.B16
	VORR   V31.B16, V31.B16, V7.B16
	VFMLA  V8.D2, V4.D2, V6.D2       // acc = -0.0 + src * dst
	VFMLA  V9.D2, V5.D2, V7.D2
	VST1.P [V6.D2, V7.D2], 32(R0)

	SUBS $1, R4
	BNE  mulinplace_quad_loop

mulinplace_tail:
	CBZ R5, mulinplace_done

mulinplace_scalar:
	FMOVD (R0), F0            // Load from dst
	FMOVD (R1), F1            // Load from src
	FMULD F1, F0, F0          // F0 = dst * src
	FMOVD F0, (R0)            // Store back to dst

	ADD  $8, R0
	ADD  $8, R1
	SUBS $1, R5
	BNE  mulinplace_scalar

mulinplace_done:
	RET
