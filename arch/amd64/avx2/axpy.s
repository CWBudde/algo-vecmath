//go:build !purego && amd64

#include "textflag.h"

// func addScaledBlockInPlaceAVX2(dst, src []float64, scale float64)
// AXPY: dst[i] += src[i] * scale
// Uses AVX2 to process 4 float64 values at once.
//
// Deliberately VMULPD + VADDPD rather than VFMADD: the AVX2 feature bit does
// not by itself guarantee FMA, and the separate rounding matches what the Go
// compiler emits for the generic implementation on amd64, which does not
// contract x*y + z.
TEXT ·addScaledBlockInPlaceAVX2(SB), NOSPLIT, $0-56
	MOVQ  dst_base+0(FP), DI  // dst.data
	MOVQ  src_base+24(FP), SI // src.data
	MOVQ  dst_len+8(FP), CX   // len(dst)
	MOVSD scale+48(FP), X1    // scale value

	// Broadcast scale to all 4 lanes of Y1
	VBROADCASTSD X1, Y1

	CMPQ CX, $4
	JL   axpy_scalar

	MOVQ CX, AX
	SHRQ $2, AX
	ANDQ $3, CX

axpy_avx2_loop:
	VMOVUPD (SI), Y0          // Load 4 float64 from src
	VMULPD  Y1, Y0, Y0        // Y0 = src * scale
	VMOVUPD (DI), Y2          // Load 4 float64 from dst
	VADDPD  Y0, Y2, Y2        // Y2 = dst + src*scale
	VMOVUPD Y2, (DI)          // Store to dst

	ADDQ $32, SI
	ADDQ $32, DI
	DECQ AX
	JNZ  axpy_avx2_loop

	TESTQ CX, CX
	JZ    axpy_done

axpy_scalar:
	MOVSD (SI), X0
	MULSD X1, X0
	ADDSD (DI), X0
	MOVSD X0, (DI)

	ADDQ $8, SI
	ADDQ $8, DI
	DECQ CX
	JNZ  axpy_scalar

axpy_done:
	VZEROUPPER
	RET
