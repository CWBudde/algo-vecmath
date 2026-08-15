//go:build !purego && arm64

#include "textflag.h"

// Additive identity for reconstructing a plain multiply out of VFMLA.
//
// VFMLA is the only vector floating-point arithmetic mnemonic the Go assembler
// accepts on arm64, so `dst = src * scale` has to be expressed as
// `acc = identity; acc += src * scale`.  FMA rounds once, so the result is
// exactly src*scale -- but the identity must be -0.0 rather than +0.0.  With
// +0.0 a product of -0.0 would come back as +0.0, because -0.0 + +0.0 = +0.0
// under round-to-nearest, and that would disagree with FMULD on the sign of
// zero.  With -0.0 both signs are preserved: -0.0 + -0.0 = -0.0.
DATA ·negZero<>(SB)/8, $0x8000000000000000
DATA ·negZero<>+8(SB)/8, $0x8000000000000000
GLOBL ·negZero<>(SB), RODATA, $16

// func scaleBlockNEON(dst, src []float64, scale float64)
// Scale: dst[i] = src[i] * scale
//
// Four float64 per iteration in two V registers, mirroring axpy.s.
TEXT ·scaleBlockNEON(SB), NOSPLIT, $0-56
	MOVD  dst_base+0(FP), R0
	MOVD  src_base+24(FP), R1
	MOVD  dst_len+8(FP), R3
	MOVD  scale+48(FP), R2     // scale bits, for the vector broadcast
	FMOVD scale+48(FP), F3     // scale, for the scalar tail

	VDUP R2, V2.D2             // V2 = {scale, scale}

	MOVD $·negZero<>(SB), R6
	VLD1 (R6), [V31.D2]        // V31 = {-0.0, -0.0}

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, scaleblock_tail

scaleblock_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // src[i..i+3]
	VORR   V31.B16, V31.B16, V6.B16  // seed accumulators with -0.0
	VORR   V31.B16, V31.B16, V7.B16
	VFMLA  V2.D2, V4.D2, V6.D2       // acc = -0.0 + src * scale
	VFMLA  V2.D2, V5.D2, V7.D2
	VST1.P [V6.D2, V7.D2], 32(R0)

	SUBS $1, R4
	BNE  scaleblock_quad_loop

scaleblock_tail:
	CBZ R5, scaleblock_done

scaleblock_scalar:
	FMOVD (R1), F0
	FMULD F3, F0, F0
	FMOVD F0, (R0)

	ADD  $8, R1
	ADD  $8, R0
	SUBS $1, R5
	BNE  scaleblock_scalar

scaleblock_done:
	RET

// func scaleBlockInPlaceNEON(dst []float64, scale float64)
// In-place scale: dst[i] *= scale
TEXT ·scaleBlockInPlaceNEON(SB), NOSPLIT, $0-32
	MOVD  dst_base+0(FP), R0
	MOVD  dst_len+8(FP), R3
	MOVD  scale+24(FP), R2
	FMOVD scale+24(FP), F3

	VDUP R2, V2.D2

	MOVD $·negZero<>(SB), R6
	VLD1 (R6), [V31.D2]

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, scaleinplace_tail

scaleinplace_quad_loop:
	VLD1  (R0), [V4.D2, V5.D2]
	VORR  V31.B16, V31.B16, V6.B16
	VORR  V31.B16, V31.B16, V7.B16
	VFMLA V2.D2, V4.D2, V6.D2
	VFMLA V2.D2, V5.D2, V7.D2
	VST1.P [V6.D2, V7.D2], 32(R0)

	SUBS $1, R4
	BNE  scaleinplace_quad_loop

scaleinplace_tail:
	CBZ R5, scaleinplace_done

scaleinplace_scalar:
	FMOVD (R0), F0
	FMULD F3, F0, F0
	FMOVD F0, (R0)

	ADD  $8, R0
	SUBS $1, R5
	BNE  scaleinplace_scalar

scaleinplace_done:
	RET
