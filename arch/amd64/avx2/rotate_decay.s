//go:build !purego && amd64

#include "textflag.h"

// func rotateDecayComplexF32AVX2(re, im, cosW, sinW, decay []float32)
// Rotates and damps complex oscillators in place using AVX2.
// Processes 8 float32 values per iteration.
//
// For each i:
//   re[i] = decay[i] * (re[i]*cosW[i] - im[i]*sinW[i])
//   im[i] = decay[i] * (re[i]*sinW[i] + im[i]*cosW[i])
TEXT ·rotateDecayComplexF32AVX2(SB), NOSPLIT, $0-120
	MOVQ re_base+0(FP), DI      // re.data
	MOVQ im_base+24(FP), SI     // im.data
	MOVQ cosW_base+48(FP), DX   // cosW.data
	MOVQ sinW_base+72(FP), R8   // sinW.data
	MOVQ decay_base+96(FP), R9  // decay.data
	MOVQ re_len+8(FP), CX       // len(re)

	CMPQ CX, $8
	JL   rdcf32_scalar

	MOVQ CX, AX
	SHRQ $3, AX                 // AX = count / 8
	ANDQ $7, CX                 // CX = count % 8

rdcf32_avx2_loop:
	VMOVUPS (DI), Y0            // Y0 = re
	VMOVUPS (SI), Y1            // Y1 = im
	VMOVUPS (DX), Y2            // Y2 = cosW
	VMOVUPS (R8), Y3            // Y3 = sinW
	VMOVUPS (R9), Y4            // Y4 = decay

	VMULPS  Y2, Y0, Y5          // Y5 = re * cosW
	VMULPS  Y3, Y1, Y6          // Y6 = im * sinW
	VSUBPS  Y6, Y5, Y5          // Y5 = re*cosW - im*sinW

	VMULPS  Y3, Y0, Y7          // Y7 = re * sinW
	VMULPS  Y2, Y1, Y6          // Y6 = im * cosW
	VADDPS  Y6, Y7, Y7          // Y7 = re*sinW + im*cosW

	VMULPS  Y4, Y5, Y5          // Y5 = decay * newRe
	VMULPS  Y4, Y7, Y7          // Y7 = decay * newIm

	VMOVUPS Y5, (DI)            // Store re
	VMOVUPS Y7, (SI)            // Store im

	ADDQ $32, DI
	ADDQ $32, SI
	ADDQ $32, DX
	ADDQ $32, R8
	ADDQ $32, R9
	DECQ AX
	JNZ  rdcf32_avx2_loop

	TESTQ CX, CX
	JZ    rdcf32_done

rdcf32_scalar:
	MOVSS  (DI), X0             // X0 = re[i]
	MOVSS  (SI), X1             // X1 = im[i]
	MOVSS  (DX), X2             // X2 = cosW[i]
	MOVSS  (R8), X3             // X3 = sinW[i]
	MOVSS  (R9), X4             // X4 = decay[i]

	MOVSS  X0, X5
	MULSS  X2, X5               // X5 = re * cosW
	MOVSS  X1, X6
	MULSS  X3, X6               // X6 = im * sinW
	SUBSS  X6, X5               // X5 = re*cosW - im*sinW

	MULSS  X3, X0               // X0 = re * sinW
	MULSS  X2, X1               // X1 = im * cosW
	ADDSS  X1, X0               // X0 = re*sinW + im*cosW

	MULSS  X4, X5               // X5 = decay * newRe
	MULSS  X4, X0               // X0 = decay * newIm

	MOVSS  X5, (DI)             // Store re
	MOVSS  X0, (SI)             // Store im

	ADDQ $4, DI
	ADDQ $4, SI
	ADDQ $4, DX
	ADDQ $4, R8
	ADDQ $4, R9
	DECQ CX
	JNZ  rdcf32_scalar

rdcf32_done:
	VZEROUPPER
	RET

// func rotateDecayAccumulateF32AVX2(dst []float32, re, im, cosW, sinW, decay, gain []float32)
// Rotates, damps, and accumulates weighted real part using AVX2.
// Processes 8 float32 values per iteration.
//
// For each i:
//   re[i] = decay[i] * (re[i]*cosW[i] - im[i]*sinW[i])
//   im[i] = decay[i] * (re[i]*sinW[i] + im[i]*cosW[i])
//   dst[i] += gain[i] * re[i]
TEXT ·rotateDecayAccumulateF32AVX2(SB), NOSPLIT, $0-168
	MOVQ dst_base+0(FP), DI      // dst.data
	MOVQ re_base+24(FP), SI      // re.data
	MOVQ im_base+48(FP), DX      // im.data
	MOVQ cosW_base+72(FP), R8    // cosW.data
	MOVQ sinW_base+96(FP), R9    // sinW.data
	MOVQ decay_base+120(FP), R10 // decay.data
	MOVQ gain_base+144(FP), R11  // gain.data
	MOVQ re_len+32(FP), CX       // len(re)

	CMPQ CX, $8
	JL   rdaf32_scalar

	MOVQ CX, AX
	SHRQ $3, AX                  // AX = count / 8
	ANDQ $7, CX                  // CX = count % 8

rdaf32_avx2_loop:
	VMOVUPS (SI), Y0             // Y0 = re
	VMOVUPS (DX), Y1             // Y1 = im
	VMOVUPS (R8), Y2             // Y2 = cosW
	VMOVUPS (R9), Y3             // Y3 = sinW
	VMOVUPS (R10), Y4            // Y4 = decay

	VMULPS  Y2, Y0, Y5           // Y5 = re * cosW
	VMULPS  Y3, Y1, Y6           // Y6 = im * sinW
	VSUBPS  Y6, Y5, Y5           // Y5 = re*cosW - im*sinW

	VMULPS  Y3, Y0, Y7           // Y7 = re * sinW
	VMULPS  Y2, Y1, Y6           // Y6 = im * cosW
	VADDPS  Y6, Y7, Y7           // Y7 = re*sinW + im*cosW

	VMULPS  Y4, Y5, Y5           // Y5 = decay * newRe
	VMULPS  Y4, Y7, Y7           // Y7 = decay * newIm

	VMOVUPS Y5, (SI)             // Store re
	VMOVUPS Y7, (DX)             // Store im

	// dst[i] += gain[i] * re[i]
	VMOVUPS (R11), Y8            // Y8 = gain
	VMOVUPS (DI), Y9             // Y9 = dst
	VMULPS  Y5, Y8, Y8           // Y8 = gain * newRe
	VADDPS  Y8, Y9, Y9           // Y9 = dst + gain * newRe
	VMOVUPS Y9, (DI)             // Store dst

	ADDQ $32, DI
	ADDQ $32, SI
	ADDQ $32, DX
	ADDQ $32, R8
	ADDQ $32, R9
	ADDQ $32, R10
	ADDQ $32, R11
	DECQ AX
	JNZ  rdaf32_avx2_loop

	TESTQ CX, CX
	JZ    rdaf32_done

rdaf32_scalar:
	MOVSS  (SI), X0              // X0 = re[i]
	MOVSS  (DX), X1              // X1 = im[i]
	MOVSS  (R8), X2              // X2 = cosW[i]
	MOVSS  (R9), X3              // X3 = sinW[i]
	MOVSS  (R10), X4             // X4 = decay[i]

	MOVSS  X0, X5
	MULSS  X2, X5                // X5 = re * cosW
	MOVSS  X1, X6
	MULSS  X3, X6                // X6 = im * sinW
	SUBSS  X6, X5                // X5 = re*cosW - im*sinW

	MULSS  X3, X0                // X0 = re * sinW
	MULSS  X2, X1                // X1 = im * cosW
	ADDSS  X1, X0                // X0 = re*sinW + im*cosW

	MULSS  X4, X5                // X5 = decay * newRe
	MULSS  X4, X0                // X0 = decay * newIm

	MOVSS  X5, (SI)              // Store re
	MOVSS  X0, (DX)              // Store im

	// dst[i] += gain[i] * re[i]
	MOVSS  (R11), X7             // X7 = gain[i]
	MULSS  X5, X7                // X7 = gain * newRe
	ADDSS  (DI), X7              // X7 = dst + gain * newRe
	MOVSS  X7, (DI)              // Store dst

	ADDQ $4, DI
	ADDQ $4, SI
	ADDQ $4, DX
	ADDQ $4, R8
	ADDQ $4, R9
	ADDQ $4, R10
	ADDQ $4, R11
	DECQ CX
	JNZ  rdaf32_scalar

rdaf32_done:
	VZEROUPPER
	RET
