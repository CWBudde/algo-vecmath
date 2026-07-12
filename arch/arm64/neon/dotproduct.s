//go:build !purego && arm64

#include "textflag.h"

// func dotProductNEON(a, b []float64) float64
// Two independent accumulators over FLDPD pairs break the FP dependency
// chain; FMADDD fuses each multiply-accumulate.
TEXT ·dotProductNEON(SB), NOSPLIT, $0-56
	MOVD a_base+0(FP), R0
	MOVD b_base+24(FP), R1
	MOVD a_len+8(FP), R2

	FMOVD $0.0, F0            // accumulator (even elements)
	FMOVD $0.0, F1            // accumulator (odd elements)

	CMP $2, R2
	BLT tail

	ANDS $1, R2, R5           // R5 = len % 2
	LSR  $1, R2, R4           // R4 = len / 2

pair_loop:
	FLDPD (R0), (F2, F3)      // a[i], a[i+1]
	FLDPD (R1), (F4, F5)      // b[i], b[i+1]
	FMADDD F4, F0, F2, F0     // F0 += a[i] * b[i]
	FMADDD F5, F1, F3, F1     // F1 += a[i+1] * b[i+1]
	ADD $16, R0
	ADD $16, R1
	SUBS $1, R4
	BNE pair_loop

	FADDD F1, F0, F0          // combine accumulators
	CBZ R5, done

	FMOVD (R0), F2            // remaining element
	FMOVD (R1), F4
	FMADDD F4, F0, F2, F0
	B done

tail:
	// len < 2: zero or one element
	CBZ R2, done
	FMOVD (R0), F2
	FMOVD (R1), F4
	FMADDD F4, F0, F2, F0

done:
	FMOVD F0, ret+48(FP)
	RET
