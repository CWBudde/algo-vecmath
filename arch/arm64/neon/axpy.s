//go:build !purego && arm64

#include "textflag.h"

// func addScaledBlockInPlaceNEON(dst, src []float64, scale float64)
// AXPY: dst[i] += src[i] * scale
//
// VFMLA is the only vector floating-point arithmetic mnemonic the Go
// assembler accepts on arm64, and it is exactly this operation, so the main
// loop is four float64 per iteration in two V registers.
//
// Both the vector and the scalar tail multiply-accumulate are fused, which
// matches what the compiler emits for the generic Go implementation on arm64
// (it contracts dst[i] + src[i]*scale into FMADDD).
TEXT ·addScaledBlockInPlaceNEON(SB), NOSPLIT, $0-56
	MOVD  dst_base+0(FP), R0
	MOVD  src_base+24(FP), R1
	MOVD  dst_len+8(FP), R3
	MOVD  scale+48(FP), R2     // scale bits, for the vector broadcast
	FMOVD scale+48(FP), F3     // scale, for the scalar tail

	VDUP R2, V2.D2             // V2 = {scale, scale}

	LSR $2, R3, R4             // R4 = len / 4 (quads)
	AND $3, R3, R5             // R5 = len % 4 (tail)
	CBZ R4, axpy_tail

axpy_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // src[i..i+3]
	VLD1   (R0), [V6.D2, V7.D2]      // dst[i..i+3]
	VFMLA  V2.D2, V4.D2, V6.D2       // dst += src * scale
	VFMLA  V2.D2, V5.D2, V7.D2
	VST1.P [V6.D2, V7.D2], 32(R0)

	SUBS $1, R4
	BNE  axpy_quad_loop

axpy_tail:
	CBZ R5, axpy_done

axpy_tail_loop:
	FMOVD  (R1), F0
	FMOVD  (R0), F1
	FMADDD F3, F1, F0, F1      // F1 = F1 + F0*F3
	FMOVD  F1, (R0)

	ADD  $8, R1
	ADD  $8, R0
	SUBS $1, R5
	BNE  axpy_tail_loop

axpy_done:
	RET
