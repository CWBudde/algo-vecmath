//go:build !purego && amd64

#include "textflag.h"

// func rotateDecayComplexF32SSE2(re, im, cosW, sinW, decay []float32)
// Rotates and damps complex oscillators in place using SSE2.
// Processes 4 float32 values per iteration.
//
// For each i:
//   re[i] = decay[i] * (re[i]*cosW[i] - im[i]*sinW[i])
//   im[i] = decay[i] * (re[i]*sinW[i] + im[i]*cosW[i])
TEXT ·rotateDecayComplexF32SSE2(SB), NOSPLIT, $0-120
	MOVQ re_base+0(FP), DI      // re.data
	MOVQ im_base+24(FP), SI     // im.data
	MOVQ cosW_base+48(FP), DX   // cosW.data
	MOVQ sinW_base+72(FP), R8   // sinW.data
	MOVQ decay_base+96(FP), R9  // decay.data
	MOVQ re_len+8(FP), CX       // len(re)

	CMPQ CX, $4
	JL   rdcf32s_scalar

	MOVQ CX, AX
	SHRQ $2, AX                 // AX = count / 4
	ANDQ $3, CX                 // CX = count % 4

rdcf32s_sse2_loop:
	MOVUPS (DI), X0              // X0 = re
	MOVUPS (SI), X1              // X1 = im
	MOVUPS (DX), X2              // X2 = cosW
	MOVUPS (R8), X3              // X3 = sinW
	MOVUPS (R9), X4              // X4 = decay

	MOVAPS X0, X5                // X5 = re (copy)
	MULPS  X2, X5                // X5 = re * cosW
	MOVAPS X1, X6                // X6 = im (copy)
	MULPS  X3, X6                // X6 = im * sinW
	SUBPS  X6, X5                // X5 = re*cosW - im*sinW

	MULPS  X3, X0                // X0 = re * sinW
	MULPS  X2, X1                // X1 = im * cosW
	ADDPS  X1, X0                // X0 = re*sinW + im*cosW

	MULPS  X4, X5                // X5 = decay * newRe
	MULPS  X4, X0                // X0 = decay * newIm

	MOVUPS X5, (DI)              // Store re
	MOVUPS X0, (SI)              // Store im

	ADDQ $16, DI
	ADDQ $16, SI
	ADDQ $16, DX
	ADDQ $16, R8
	ADDQ $16, R9
	DECQ AX
	JNZ  rdcf32s_sse2_loop

	TESTQ CX, CX
	JZ    rdcf32s_done

rdcf32s_scalar:
	MOVSS  (DI), X0              // X0 = re[i]
	MOVSS  (SI), X1              // X1 = im[i]
	MOVSS  (DX), X2              // X2 = cosW[i]
	MOVSS  (R8), X3              // X3 = sinW[i]
	MOVSS  (R9), X4              // X4 = decay[i]

	MOVAPS X0, X5
	MULSS  X2, X5                // X5 = re * cosW
	MOVAPS X1, X6
	MULSS  X3, X6                // X6 = im * sinW
	SUBSS  X6, X5                // X5 = re*cosW - im*sinW

	MULSS  X3, X0                // X0 = re * sinW
	MULSS  X2, X1                // X1 = im * cosW
	ADDSS  X1, X0                // X0 = re*sinW + im*cosW

	MULSS  X4, X5                // X5 = decay * newRe
	MULSS  X4, X0                // X0 = decay * newIm

	MOVSS  X5, (DI)              // Store re
	MOVSS  X0, (SI)              // Store im

	ADDQ $4, DI
	ADDQ $4, SI
	ADDQ $4, DX
	ADDQ $4, R8
	ADDQ $4, R9
	DECQ CX
	JNZ  rdcf32s_scalar

rdcf32s_done:
	RET

// func rotateDecayAccumulateF32SSE2(dst []float32, re, im, cosW, sinW, decay, gain []float32)
// Rotates, damps, and accumulates weighted real part using SSE2.
// Processes 4 float32 values per iteration.
TEXT ·rotateDecayAccumulateF32SSE2(SB), NOSPLIT, $0-168
	MOVQ dst_base+0(FP), DI      // dst.data
	MOVQ re_base+24(FP), SI      // re.data
	MOVQ im_base+48(FP), DX      // im.data
	MOVQ cosW_base+72(FP), R8    // cosW.data
	MOVQ sinW_base+96(FP), R9    // sinW.data
	MOVQ decay_base+120(FP), R10 // decay.data
	MOVQ gain_base+144(FP), R11  // gain.data
	MOVQ re_len+32(FP), CX       // len(re)

	CMPQ CX, $4
	JL   rdaf32s_scalar

	MOVQ CX, AX
	SHRQ $2, AX                  // AX = count / 4
	ANDQ $3, CX                  // CX = count % 4

rdaf32s_sse2_loop:
	MOVUPS (SI), X0               // X0 = re
	MOVUPS (DX), X1               // X1 = im
	MOVUPS (R8), X2               // X2 = cosW
	MOVUPS (R9), X3               // X3 = sinW
	MOVUPS (R10), X4              // X4 = decay

	MOVAPS X0, X5                 // X5 = re (copy)
	MULPS  X2, X5                 // X5 = re * cosW
	MOVAPS X1, X6                 // X6 = im (copy)
	MULPS  X3, X6                 // X6 = im * sinW
	SUBPS  X6, X5                 // X5 = re*cosW - im*sinW

	MULPS  X3, X0                 // X0 = re * sinW
	MULPS  X2, X1                 // X1 = im * cosW
	ADDPS  X1, X0                 // X0 = re*sinW + im*cosW

	MULPS  X4, X5                 // X5 = decay * newRe
	MULPS  X4, X0                 // X0 = decay * newIm

	MOVUPS X5, (SI)               // Store re
	MOVUPS X0, (DX)               // Store im

	// dst[i] += gain[i] * re[i]
	MOVUPS (R11), X7              // X7 = gain
	MULPS  X5, X7                 // X7 = gain * newRe
	MOVUPS (DI), X8               // X8 = dst
	ADDPS  X7, X8                 // X8 = dst + gain * newRe
	MOVUPS X8, (DI)               // Store dst

	ADDQ $16, DI
	ADDQ $16, SI
	ADDQ $16, DX
	ADDQ $16, R8
	ADDQ $16, R9
	ADDQ $16, R10
	ADDQ $16, R11
	DECQ AX
	JNZ  rdaf32s_sse2_loop

	TESTQ CX, CX
	JZ    rdaf32s_done

rdaf32s_scalar:
	MOVSS  (SI), X0               // X0 = re[i]
	MOVSS  (DX), X1               // X1 = im[i]
	MOVSS  (R8), X2               // X2 = cosW[i]
	MOVSS  (R9), X3               // X3 = sinW[i]
	MOVSS  (R10), X4              // X4 = decay[i]

	MOVAPS X0, X5
	MULSS  X2, X5                 // X5 = re * cosW
	MOVAPS X1, X6
	MULSS  X3, X6                 // X6 = im * sinW
	SUBSS  X6, X5                 // X5 = re*cosW - im*sinW

	MULSS  X3, X0                 // X0 = re * sinW
	MULSS  X2, X1                 // X1 = im * cosW
	ADDSS  X1, X0                 // X0 = re*sinW + im*cosW

	MULSS  X4, X5                 // X5 = decay * newRe
	MULSS  X4, X0                 // X0 = decay * newIm

	MOVSS  X5, (SI)               // Store re
	MOVSS  X0, (DX)               // Store im

	// dst[i] += gain[i] * re[i]
	MOVSS  (R11), X7              // X7 = gain[i]
	MULSS  X5, X7                 // X7 = gain * newRe
	ADDSS  (DI), X7               // X7 = dst + gain * newRe
	MOVSS  X7, (DI)               // Store dst

	ADDQ $4, DI
	ADDQ $4, SI
	ADDQ $4, DX
	ADDQ $4, R8
	ADDQ $4, R9
	ADDQ $4, R10
	ADDQ $4, R11
	DECQ CX
	JNZ  rdaf32s_scalar

rdaf32s_done:
	RET
