//go:build !purego && arm64

#include "textflag.h"

// func powerNEON(dst, re, im []float64)
// Computes power (magnitude squared): dst[i] = re[i]^2 + im[i]^2
// Processes 2 float64 per iteration via FLDPD/FSTPD paired loads/stores.
TEXT ·powerNEON(SB), NOSPLIT, $0-72
	MOVD dst_base+0(FP), R0    // dst.data
	MOVD re_base+24(FP), R1    // re.data
	MOVD im_base+48(FP), R2    // im.data
	MOVD dst_len+8(FP), R3     // len(dst)

	CMP  $2, R3
	BLT  power_scalar

	AND  $1, R3, R5            // R5 = count % 2 (remainder for scalar)
	LSR  $1, R3, R4            // R4 = count / 2 (pairs)

power_pair_loop:
	FLDPD (R1), (F0, F1)       // re[i], re[i+1]
	FLDPD (R2), (F2, F3)       // im[i], im[i+1]
	FMULD F0, F0, F0           // F0 = re[i]^2
	FMULD F2, F2, F2           // F2 = im[i]^2
	FADDD F2, F0, F0           // F0 = re[i]^2 + im[i]^2
	FMULD F1, F1, F1           // F1 = re[i+1]^2
	FMULD F3, F3, F3           // F3 = im[i+1]^2
	FADDD F3, F1, F1           // F1 = re[i+1]^2 + im[i+1]^2
	FSTPD (F0, F1), (R0)       // Store pair to dst

	ADD  $16, R1
	ADD  $16, R2
	ADD  $16, R0
	SUBS $1, R4
	BNE  power_pair_loop

	CBZ  R5, power_done
	MOVD R5, R3                // Remainder count for scalar loop

power_scalar:
	FMOVD (R1), F0             // F0 = re[i]
	FMOVD (R2), F1             // F1 = im[i]
	FMULD F0, F0, F0           // F0 = re^2
	FMULD F1, F1, F1           // F1 = im^2
	FADDD F1, F0, F0           // F0 = re^2 + im^2
	FMOVD F0, (R0)             // Store to dst

	ADD  $8, R1
	ADD  $8, R2
	ADD  $8, R0
	SUBS $1, R3
	BNE  power_scalar

power_done:
	RET
