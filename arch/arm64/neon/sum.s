//go:build !purego && arm64

#include "textflag.h"

// func sumNEON(x []float64) float64
// Two independent accumulators over FLDPD pairs break the FP dependency
// chain.
TEXT ·sumNEON(SB), NOSPLIT, $0-32
	MOVD x_base+0(FP), R0
	MOVD x_len+8(FP), R1

	FMOVD $0.0, F0            // accumulator (even elements)
	FMOVD $0.0, F1            // accumulator (odd elements)

	CMP $2, R1
	BLT tail

	ANDS $1, R1, R5           // R5 = len % 2
	LSR  $1, R1, R4           // R4 = len / 2

pair_loop:
	FLDPD (R0), (F2, F3)      // x[i], x[i+1]
	FADDD F2, F0, F0          // F0 += x[i]
	FADDD F3, F1, F1          // F1 += x[i+1]
	ADD $16, R0
	SUBS $1, R4
	BNE pair_loop

	FADDD F1, F0, F0          // combine accumulators
	CBZ R5, done

	FMOVD (R0), F2            // remaining element
	FADDD F2, F0, F0
	B done

tail:
	// len < 2: zero or one element
	CBZ R1, done
	FMOVD (R0), F2
	FADDD F2, F0, F0

done:
	FMOVD F0, ret+24(FP)
	RET
