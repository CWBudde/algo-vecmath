//go:build !purego && arm64

#include "textflag.h"

// Multiplicative identity: a sum is accumulated with VFMLA against a vector of
// ones, since VFMLA is the only vector floating-point arithmetic mnemonic the
// Go assembler accepts on arm64.  x*1.0 is exact and FMA rounds once, so each
// accumulation step is bit-identical to FADDD.
DATA ·sumOne<>(SB)/8, $0x3ff0000000000000
DATA ·sumOne<>+8(SB)/8, $0x3ff0000000000000
GLOBL ·sumOne<>(SB), RODATA, $16

// func sumNEON(x []float64) float64
//
// Four vector accumulators, two lanes each, so eight independent accumulation
// chains are in flight to cover FMA latency.  The previous revision used two
// *scalar* accumulators, which left the loop bound by the ~4-cycle FADDD
// dependency chain rather than by memory.
TEXT ·sumNEON(SB), NOSPLIT, $0-32
	MOVD x_base+0(FP), R0
	MOVD x_len+8(FP), R1

	MOVD $·sumOne<>(SB), R6
	VLD1 (R6), [V30.D2]       // V30 = {1.0, 1.0}

	VEOR V0.B16, V0.B16, V0.B16    // accumulators start at +0.0, matching
	VEOR V1.B16, V1.B16, V1.B16    // the generic `sum := 0.0`
	VEOR V2.B16, V2.B16, V2.B16
	VEOR V3.B16, V3.B16, V3.B16

	// R4 = len / 8 (octets), R5 = len % 8 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $3, R1, R4
	AND $7, R1, R5
	CBZ R4, sum_fold

sum_octet_loop:
	VLD1.P 64(R0), [V4.D2, V5.D2, V6.D2, V7.D2]    // x[i..i+7]
	VFMLA  V30.D2, V4.D2, V0.D2                    // acc += x * 1.0
	VFMLA  V30.D2, V5.D2, V1.D2
	VFMLA  V30.D2, V6.D2, V2.D2
	VFMLA  V30.D2, V7.D2, V3.D2

	SUBS $1, R4
	BNE  sum_octet_loop

sum_fold:
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

	CBZ R5, sum_done

sum_scalar:
	FMOVD (R0), F2
	FADDD F2, F0, F0

	ADD  $8, R0
	SUBS $1, R5
	BNE  sum_scalar

sum_done:
	FMOVD F0, ret+24(FP)
	RET
