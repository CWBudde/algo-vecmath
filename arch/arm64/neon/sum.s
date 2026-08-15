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
//
// Short inputs take a two-accumulator scalar path instead.  The vector form
// pays a fixed prologue (broadcast load, four accumulator clears) and a fixed
// horizontal fold, and below a couple of hundred elements that overhead costs
// more than the extra lanes win.  Without the split, 16 elements measured 0.29x
// against the scalar loop.  That range is not hypothetical: dsp/filter/fir
// calls a reduction once per output sample with as few as 32 taps.
//
// The threshold is measured, forcing each path over a size sweep on an Apple
// M5 (ns/op, best of 3):
//
//	     n:    16    32    48    64    96   128   192   256   512
//	scalar:     2     5     6     8    12    17    28    46   106
//	vector:     7     8    10    12    15    18    26    33    62
//
// so the vector form is behind through 128 and ahead from 192.  It is a higher
// crossover than dotProductNEON's 128, because this kernel's scalar path does
// half the loads per element and so is the harder one to beat.
TEXT ·sumNEON(SB), NOSPLIT, $0-32
	MOVD x_base+0(FP), R0
	MOVD x_len+8(FP), R1

	CMP $192, R1
	BLT sum_small

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

sum_octet_loop:
	VLD1.P 64(R0), [V4.D2, V5.D2, V6.D2, V7.D2]    // x[i..i+7]
	VFMLA  V30.D2, V4.D2, V0.D2                    // acc += x * 1.0
	VFMLA  V30.D2, V5.D2, V1.D2
	VFMLA  V30.D2, V6.D2, V2.D2
	VFMLA  V30.D2, V7.D2, V3.D2

	SUBS $1, R4
	BNE  sum_octet_loop

	// Collapse the four accumulators pairwise, then the two lanes.  The lane
	// collapse moves lane 1 of V0 into lane 0 of V1 directly, so that F0 and
	// F1 -- which alias the low halves of V0 and V1 -- hold the two values
	// without a round trip through general registers.  V1 is dead by this
	// point, having already been folded into V0.
	VFMLA V30.D2, V1.D2, V0.D2
	VFMLA V30.D2, V3.D2, V2.D2
	VFMLA V30.D2, V2.D2, V0.D2

	VMOV  V0.D[1], V1.D[0]
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

	// Two independent scalar accumulators over FLDPD pairs, enough to break
	// the FADDD dependency chain without any vector setup to amortise.
sum_small:
	FMOVD $0.0, F0
	FMOVD $0.0, F1

	// R4 = len / 2 (pairs), R5 = len % 2 (tail).  Both must be computed
	// before any branch that skips the pair loop.
	LSR  $1, R1, R4
	ANDS $1, R1, R5
	CBZ  R4, sum_small_combine

sum_small_pair:
	FLDPD (R0), (F2, F3)
	FADDD F2, F0, F0
	FADDD F3, F1, F1

	ADD  $16, R0
	SUBS $1, R4
	BNE  sum_small_pair

sum_small_combine:
	FADDD F1, F0, F0
	CBZ   R5, sum_small_done

	FMOVD (R0), F2
	FADDD F2, F0, F0

sum_small_done:
	FMOVD F0, ret+24(FP)
	RET
