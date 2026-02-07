//go:build !purego && amd64

#include "textflag.h"

// TPDF dither using circular buffer PRNG with additive feedback.
// SSE2 implementation: batches 2 samples, uses scalar CVTSL2SD + MULPD for conversion.
//
// PRNG per sample (sequential, matches generic Go reference):
//   Average 1: read field[pos], shift>>1, feedback to field[(pos-1)&63], pos=(pos+2)&63
//   Average 2: read field[pos], shift>>1, feedback to field[(pos-1)&63], pos=(pos+2)&63
//   sum = shifted1 + shifted2

// func generateTPDFSSE2(dst []float64, scale float64, field *[64]uint32, pos int) int
TEXT ·generateTPDFSSE2(SB), NOSPLIT, $0-56
	MOVQ  dst_base+0(FP), DI
	MOVQ  dst_len+8(FP), CX
	MOVSD scale+24(FP), X7
	MOVQ  field+32(FP), SI
	MOVQ  pos+40(FP), R8

	// Broadcast scale to both lanes of X7
	UNPCKLPD X7, X7

	// Check if we can do batched (need at least 2 samples)
	CMPQ CX, $2
	JL   gen_scalar_setup

	MOVQ CX, AX
	SHRQ $1, AX               // AX = len / 2
	ANDQ $1, CX               // CX = len % 2

gen_batch_loop:
	// --- Sample 0 ---
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

	// --- Convert 2 int32 sums to 2 float64, scale, store ---
	CVTSL2SD R12, X0           // X0 low = float64(sum0)
	CVTSL2SD R13, X1           // X1 low = float64(sum1)
	UNPCKLPD X1, X0            // X0 = {sum0, sum1}
	MULPD    X7, X0            // scale both
	MOVUPD   X0, (DI)          // store 2 float64
	ADDQ    $16, DI

	DECQ AX
	JNZ  gen_batch_loop

	TESTQ CX, CX
	JZ    gen_done

gen_scalar_setup:
gen_scalar_loop:
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
	MULSD    X7, X0
	MOVSD    X0, (DI)
	ADDQ     $8, DI

	DECQ CX
	JNZ  gen_scalar_loop

gen_done:
	MOVQ R8, ret+48(FP)
	RET


// func addDitherTPDFSSE2(dst []float64, scale float64, field *[64]uint32, pos int) int
TEXT ·addDitherTPDFSSE2(SB), NOSPLIT, $0-56
	MOVQ  dst_base+0(FP), DI
	MOVQ  dst_len+8(FP), CX
	MOVSD scale+24(FP), X7
	MOVQ  field+32(FP), SI
	MOVQ  pos+40(FP), R8

	UNPCKLPD X7, X7

	CMPQ CX, $2
	JL   add_scalar_setup

	MOVQ CX, AX
	SHRQ $1, AX
	ANDQ $1, CX

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

	// --- Convert, scale, ADD to dst ---
	CVTSL2SD R12, X0           // X0 low = float64(sum0)
	CVTSL2SD R13, X1           // X1 low = float64(sum1)
	UNPCKLPD X1, X0            // X0 = {sum0, sum1}
	MULPD    X7, X0            // scale both
	MOVUPD   (DI), X1          // load existing dst
	ADDPD    X1, X0            // add dither
	MOVUPD   X0, (DI)          // store
	ADDQ    $16, DI

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
	MULSD    X7, X0
	ADDSD    (DI), X0
	MOVSD    X0, (DI)
	ADDQ     $8, DI

	DECQ CX
	JNZ  add_scalar_loop

add_done:
	MOVQ R8, ret+48(FP)
	RET
