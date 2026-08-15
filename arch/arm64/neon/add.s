//go:build !purego && arm64

#include "textflag.h"

// Multiplicative identity for reconstructing a plain add out of VFMLA.
//
// VFMLA is the only vector floating-point arithmetic mnemonic the Go assembler
// accepts on arm64, so `dst = a + b` is expressed as `acc = b; acc += a * 1.0`.
// a*1.0 is exact and FMA rounds once, so the result is bit-identical to FADDD,
// signed zeros included.
DATA ·vecOne<>(SB)/8, $0x3ff0000000000000
DATA ·vecOne<>+8(SB)/8, $0x3ff0000000000000
GLOBL ·vecOne<>(SB), RODATA, $16

// func addBlockNEON(dst, a, b []float64)
// Element-wise add: dst[i] = a[i] + b[i]
//
// Four float64 per iteration in two V registers.  b is loaded straight into the
// accumulators, so seeding them costs nothing beyond the load we already need.
TEXT ·addBlockNEON(SB), NOSPLIT, $0-72
	MOVD dst_base+0(FP), R0   // dst.data
	MOVD a_base+24(FP), R1    // a.data
	MOVD b_base+48(FP), R2    // b.data
	MOVD dst_len+8(FP), R3    // len(dst)

	MOVD $·vecOne<>(SB), R6
	VLD1 (R6), [V30.D2]       // V30 = {1.0, 1.0}

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, addblock_tail

addblock_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // a[i..i+3]
	VLD1.P 32(R2), [V6.D2, V7.D2]    // b[i..i+3], seeds the accumulators
	VFMLA  V30.D2, V4.D2, V6.D2      // acc = b + a * 1.0
	VFMLA  V30.D2, V5.D2, V7.D2
	VST1.P [V6.D2, V7.D2], 32(R0)

	SUBS $1, R4
	BNE  addblock_quad_loop

addblock_tail:
	CBZ R5, addblock_done

addblock_scalar:
	FMOVD (R1), F0            // Load from a
	FMOVD (R2), F1            // Load from b
	FADDD F1, F0, F0          // F0 = a + b
	FMOVD F0, (R0)            // Store to dst

	ADD  $8, R1
	ADD  $8, R2
	ADD  $8, R0
	SUBS $1, R5
	BNE  addblock_scalar

addblock_done:
	RET

// func addBlockInPlaceNEON(dst, src []float64)
// In-place add: dst[i] += src[i]
TEXT ·addBlockInPlaceNEON(SB), NOSPLIT, $0-48
	MOVD dst_base+0(FP), R0   // dst.data
	MOVD src_base+24(FP), R1  // src.data
	MOVD dst_len+8(FP), R3    // len(dst)

	MOVD $·vecOne<>(SB), R6
	VLD1 (R6), [V30.D2]

	// R4 = len / 4 (quads), R5 = len % 4 (tail).  Both must be computed
	// before any branch to the tail, which counts R5 down to zero.
	LSR $2, R3, R4
	AND $3, R3, R5
	CBZ R4, addinplace_tail

addinplace_quad_loop:
	VLD1.P 32(R1), [V4.D2, V5.D2]    // src[i..i+3]
	VLD1   (R0), [V6.D2, V7.D2]      // dst[i..i+3], seeds the accumulators
	VFMLA  V30.D2, V4.D2, V6.D2      // acc = dst + src * 1.0
	VFMLA  V30.D2, V5.D2, V7.D2
	VST1.P [V6.D2, V7.D2], 32(R0)

	SUBS $1, R4
	BNE  addinplace_quad_loop

addinplace_tail:
	CBZ R5, addinplace_done

addinplace_scalar:
	FMOVD (R0), F0            // Load from dst
	FMOVD (R1), F1            // Load from src
	FADDD F1, F0, F0          // F0 = dst + src
	FMOVD F0, (R0)            // Store back to dst

	ADD  $8, R0
	ADD  $8, R1
	SUBS $1, R5
	BNE  addinplace_scalar

addinplace_done:
	RET
