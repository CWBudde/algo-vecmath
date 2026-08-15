//go:build !purego && arm64

#include "textflag.h"

// func scaleBlockNEON(dst, src []float64, scale float64)
// Scale: dst[i] = src[i] * scale
// Uses NEON-style paired operations for 2 float64 values
TEXT ·scaleBlockNEON(SB), NOSPLIT, $0-56
	MOVD  dst_base+0(FP), R0
	MOVD  src_base+24(FP), R1
	MOVD  dst_len+8(FP), R3
	FMOVD scale+48(FP), F2    // scale in F2

	// R4 = len / 2 (pairs), R5 = len % 2 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	ANDS $1, R3, R5
	LSR  $1, R3, R4
	CBZ  R4, scaleblock_tail

scaleblock_neon_loop:
	FLDPD (R1), (F0, F1)
	FMULD F2, F0, F0
	FMULD F2, F1, F1
	FSTPD (F0, F1), (R0)

	ADD $16, R1
	ADD $16, R0
	SUBS $1, R4
	BNE scaleblock_neon_loop

scaleblock_tail:
	CBZ R5, scaleblock_done

scaleblock_scalar:
	FMOVD (R1), F0
	FMULD F2, F0, F0
	FMOVD F0, (R0)

	ADD $8, R1
	ADD $8, R0
	SUBS $1, R5
	BNE scaleblock_scalar

scaleblock_done:
	RET

// func scaleBlockInPlaceNEON(dst []float64, scale float64)
// In-place scale: dst[i] *= scale
TEXT ·scaleBlockInPlaceNEON(SB), NOSPLIT, $0-32
	MOVD  dst_base+0(FP), R0
	MOVD  dst_len+8(FP), R3
	FMOVD scale+24(FP), F2

	// R4 = len / 2 (pairs), R5 = len % 2 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	ANDS $1, R3, R5
	LSR  $1, R3, R4
	CBZ  R4, scaleinplace_tail

scaleinplace_neon_loop:
	FLDPD (R0), (F0, F1)
	FMULD F2, F0, F0
	FMULD F2, F1, F1
	FSTPD (F0, F1), (R0)

	ADD $16, R0
	SUBS $1, R4
	BNE scaleinplace_neon_loop

scaleinplace_tail:
	CBZ R5, scaleinplace_done

scaleinplace_scalar:
	FMOVD (R0), F0
	FMULD F2, F0, F0
	FMOVD F0, (R0)

	ADD $8, R0
	SUBS $1, R5
	BNE scaleinplace_scalar

scaleinplace_done:
	RET
