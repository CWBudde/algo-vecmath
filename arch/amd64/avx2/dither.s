//go:build !purego && amd64

#include "textflag.h"

// TPDF dither using circular buffer PRNG with additive feedback.
//
// PRNG algorithm per sample (sequential, matches generic Go reference):
//   Average 1: read field[pos], shift right by 1, feedback to field[(pos-1)&63], advance pos by 2
//   Average 2: read field[pos], shift right by 1, feedback to field[(pos-1)&63], advance pos by 2
//   sum = shifted1 + shifted2
//
// SIMD optimization: batch 4 scalar PRNG sums, then VCVTDQ2PD + VMULPD + VMOVUPD.

// Macro-like block: generate one TPDF sample sum into target register.
// Uses: R8=pos, SI=field, R9/R10/R11=scratch, BX=raw value
// Output: target register holds int32 sum
// Clobbers: R9, R10, R11, BX

// func generateTPDFAVX2(dst []float64, scale float64, field *[64]uint32, pos int) int
TEXT ·generateTPDFAVX2(SB), NOSPLIT, $16-56
	MOVQ  dst_base+0(FP), DI   // DI = dst pointer
	MOVQ  dst_len+8(FP), CX    // CX = len(dst)
	MOVSD scale+24(FP), X8     // X8 = scale (float64)
	MOVQ  field+32(FP), SI     // SI = field pointer
	MOVQ  pos+40(FP), R8       // R8 = pos (index 0-63)

	// Broadcast scale to YMM for 4-wide multiply
	VBROADCASTSD X8, Y8        // Y8 = {scale, scale, scale, scale}

	// Check if we can do batched output (need at least 4 samples)
	CMPQ CX, $4
	JL   gen_scalar_setup

	// Batched loop: generate 4 scalar PRNG sums, then SIMD convert+scale+store
	MOVQ CX, AX
	SHRQ $2, AX               // AX = len / 4
	ANDQ $3, CX               // CX = len % 4

gen_batch_loop:
	// --- Sample 0 ---
	// Average 1
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX      // BX = field[pos]
	MOVL  BX, R12
	SARL  $1, R12              // R12 = int32(val) >> 1
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)     // field[(pos-1)&63] += val
	ADDQ  $2, R8
	ANDQ  $63, R8
	// Average 2
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R12             // sum0 = shifted1 + shifted2
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Sample 1 ---
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R13
	SARL  $1, R13
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R13
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Sample 2 ---
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R14
	SARL  $1, R14
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R14
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Sample 3 ---
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R15
	SARL  $1, R15
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R15
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Store 4 int32 sums to stack, SIMD convert+scale+store ---
	MOVL  R12, 0(SP)
	MOVL  R13, 4(SP)
	MOVL  R14, 8(SP)
	MOVL  R15, 12(SP)

	VCVTDQ2PD 0(SP), Y0       // convert 4 int32 -> 4 float64
	VMULPD    Y8, Y0, Y0      // scale
	VMOVUPD   Y0, (DI)        // store 4 float64
	ADDQ      $32, DI

	DECQ AX
	JNZ  gen_batch_loop

	TESTQ CX, CX
	JZ    gen_done

gen_scalar_setup:
	// Scalar tail: one sample at a time
gen_scalar_loop:
	// Average 1
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R12
	SARL  $1, R12
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	// Average 2
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R12
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	CVTSL2SD R12, X0
	MULSD    X8, X0
	MOVSD    X0, (DI)
	ADDQ     $8, DI

	DECQ CX
	JNZ  gen_scalar_loop

gen_done:
	MOVQ R8, ret+48(FP)
	VZEROUPPER
	RET


// func addDitherTPDFAVX2(dst []float64, scale float64, field *[64]uint32, pos int) int
TEXT ·addDitherTPDFAVX2(SB), NOSPLIT, $16-56
	MOVQ  dst_base+0(FP), DI
	MOVQ  dst_len+8(FP), CX
	MOVSD scale+24(FP), X8
	MOVQ  field+32(FP), SI
	MOVQ  pos+40(FP), R8

	VBROADCASTSD X8, Y8

	CMPQ CX, $4
	JL   add_scalar_setup

	MOVQ CX, AX
	SHRQ $2, AX
	ANDQ $3, CX

add_batch_loop:
	// --- Sample 0 ---
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R12
	SARL  $1, R12
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R12
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Sample 1 ---
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R13
	SARL  $1, R13
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R13
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Sample 2 ---
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R14
	SARL  $1, R14
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R14
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Sample 3 ---
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R15
	SARL  $1, R15
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R15
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	// --- Store sums, SIMD convert+scale, ADD to dst ---
	MOVL  R12, 0(SP)
	MOVL  R13, 4(SP)
	MOVL  R14, 8(SP)
	MOVL  R15, 12(SP)

	VCVTDQ2PD 0(SP), Y0
	VMULPD    Y8, Y0, Y0
	VMOVUPD   (DI), Y1         // load existing dst
	VADDPD    Y1, Y0, Y0       // add dither
	VMOVUPD   Y0, (DI)
	ADDQ      $32, DI

	DECQ AX
	JNZ  add_batch_loop

	TESTQ CX, CX
	JZ    add_done

add_scalar_setup:
add_scalar_loop:
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R12
	SARL  $1, R12
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8
	MOVQ  R8, R9
	SHLQ  $2, R9
	MOVL  (SI)(R9*1), BX
	MOVL  BX, R10
	SARL  $1, R10
	ADDL  R10, R12
	MOVQ  R8, R10
	SUBQ  $1, R10
	ANDQ  $63, R10
	MOVQ  R10, R11
	SHLQ  $2, R11
	ADDL  BX, (SI)(R11*1)
	ADDQ  $2, R8
	ANDQ  $63, R8

	CVTSL2SD R12, X0
	MULSD    X8, X0
	ADDSD    (DI), X0
	MOVSD    X0, (DI)
	ADDQ     $8, DI

	DECQ CX
	JNZ  add_scalar_loop

add_done:
	MOVQ R8, ret+48(FP)
	VZEROUPPER
	RET
