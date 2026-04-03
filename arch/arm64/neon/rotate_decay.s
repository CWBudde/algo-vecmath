//go:build !purego && arm64

#include "textflag.h"

// func rotateDecayComplexF32NEON(re, im, cosW, sinW, decay []float32)
// Rotates and damps complex oscillators in place using NEON.
// Processes 4 float32 values per iteration.
//
// For each i:
//   re[i] = decay[i] * (re[i]*cosW[i] - im[i]*sinW[i])
//   im[i] = decay[i] * (re[i]*sinW[i] + im[i]*cosW[i])
TEXT ·rotateDecayComplexF32NEON(SB), NOSPLIT, $0-120
	MOVD re_base+0(FP), R0      // re.data
	MOVD im_base+24(FP), R1     // im.data
	MOVD cosW_base+48(FP), R2   // cosW.data
	MOVD sinW_base+72(FP), R3   // sinW.data
	MOVD decay_base+96(FP), R4  // decay.data
	MOVD re_len+8(FP), R5       // len(re)

	CMP  $4, R5
	BLT  rdcf32n_scalar

	AND  $3, R5, R7             // R7 = count % 4 (remainder)
	LSR  $2, R5, R6             // R6 = count / 4

rdcf32n_neon_loop:
	VLD1 (R0), [V0.S4]          // V0 = re
	VLD1 (R1), [V1.S4]          // V1 = im
	VLD1 (R2), [V2.S4]          // V2 = cosW
	VLD1 (R3), [V3.S4]          // V3 = sinW
	VLD1 (R4), [V4.S4]          // V4 = decay

	FMUL V0.S4, V2.S4, V5.S4    // V5 = re * cosW
	FMUL V1.S4, V3.S4, V6.S4    // V6 = im * sinW
	FSUB V6.S4, V5.S4, V5.S4    // V5 = re*cosW - im*sinW

	FMUL V0.S4, V3.S4, V7.S4    // V7 = re * sinW
	FMUL V1.S4, V2.S4, V6.S4    // V6 = im * cosW
	FADD V6.S4, V7.S4, V7.S4    // V7 = re*sinW + im*cosW

	FMUL V4.S4, V5.S4, V5.S4    // V5 = decay * newRe
	FMUL V4.S4, V7.S4, V7.S4    // V7 = decay * newIm

	VST1 [V5.S4], (R0)          // Store re
	VST1 [V7.S4], (R1)          // Store im

	ADD  $16, R0
	ADD  $16, R1
	ADD  $16, R2
	ADD  $16, R3
	ADD  $16, R4
	SUBS $1, R6
	BNE  rdcf32n_neon_loop

	CBZ  R7, rdcf32n_done
	MOVD R7, R5                  // Restore remainder count for scalar

rdcf32n_scalar:
	FMOVS (R0), F0               // F0 = re[i]
	FMOVS (R1), F1               // F1 = im[i]
	FMOVS (R2), F2               // F2 = cosW[i]
	FMOVS (R3), F3               // F3 = sinW[i]
	FMOVS (R4), F4               // F4 = decay[i]

	FMULS F0, F2, F5             // F5 = re * cosW
	FMULS F1, F3, F6             // F6 = im * sinW
	FSUBS F6, F5, F5             // F5 = re*cosW - im*sinW

	FMULS F0, F3, F7             // F7 = re * sinW
	FMULS F1, F2, F6             // F6 = im * cosW
	FADDS F6, F7, F7             // F7 = re*sinW + im*cosW

	FMULS F4, F5, F5             // F5 = decay * newRe
	FMULS F4, F7, F7             // F7 = decay * newIm

	FMOVS F5, (R0)              // Store re
	FMOVS F7, (R1)              // Store im

	ADD  $4, R0
	ADD  $4, R1
	ADD  $4, R2
	ADD  $4, R3
	ADD  $4, R4
	SUBS $1, R5
	BNE  rdcf32n_scalar

rdcf32n_done:
	RET

// func rotateDecayAccumulateF32NEON(dst []float32, re, im, cosW, sinW, decay, gain []float32)
// Rotates, damps, and accumulates weighted real part using NEON.
// Processes 4 float32 values per iteration.
TEXT ·rotateDecayAccumulateF32NEON(SB), NOSPLIT, $0-168
	MOVD dst_base+0(FP), R0       // dst.data
	MOVD re_base+24(FP), R1       // re.data
	MOVD im_base+48(FP), R2       // im.data
	MOVD cosW_base+72(FP), R3     // cosW.data
	MOVD sinW_base+96(FP), R4     // sinW.data
	MOVD decay_base+120(FP), R5   // decay.data
	MOVD gain_base+144(FP), R6    // gain.data
	MOVD re_len+32(FP), R7        // len(re)

	CMP  $4, R7
	BLT  rdaf32n_scalar

	AND  $3, R7, R9              // R9 = count % 4 (remainder)
	LSR  $2, R7, R8              // R8 = count / 4

rdaf32n_neon_loop:
	VLD1 (R1), [V0.S4]           // V0 = re
	VLD1 (R2), [V1.S4]           // V1 = im
	VLD1 (R3), [V2.S4]           // V2 = cosW
	VLD1 (R4), [V3.S4]           // V3 = sinW
	VLD1 (R5), [V4.S4]           // V4 = decay

	FMUL V0.S4, V2.S4, V5.S4     // V5 = re * cosW
	FMUL V1.S4, V3.S4, V6.S4     // V6 = im * sinW
	FSUB V6.S4, V5.S4, V5.S4     // V5 = re*cosW - im*sinW

	FMUL V0.S4, V3.S4, V7.S4     // V7 = re * sinW
	FMUL V1.S4, V2.S4, V6.S4     // V6 = im * cosW
	FADD V6.S4, V7.S4, V7.S4     // V7 = re*sinW + im*cosW

	FMUL V4.S4, V5.S4, V5.S4     // V5 = decay * newRe
	FMUL V4.S4, V7.S4, V7.S4     // V7 = decay * newIm

	VST1 [V5.S4], (R1)           // Store re
	VST1 [V7.S4], (R2)           // Store im

	// dst[i] += gain[i] * re[i]
	VLD1 (R6), [V8.S4]           // V8 = gain
	VLD1 (R0), [V9.S4]           // V9 = dst
	FMUL V5.S4, V8.S4, V8.S4     // V8 = gain * newRe
	FADD V8.S4, V9.S4, V9.S4     // V9 = dst + gain * newRe
	VST1 [V9.S4], (R0)           // Store dst

	ADD  $16, R0
	ADD  $16, R1
	ADD  $16, R2
	ADD  $16, R3
	ADD  $16, R4
	ADD  $16, R5
	ADD  $16, R6
	SUBS $1, R8
	BNE  rdaf32n_neon_loop

	CBZ  R9, rdaf32n_done
	MOVD R9, R7                  // Restore remainder count for scalar

rdaf32n_scalar:
	FMOVS (R1), F0                // F0 = re[i]
	FMOVS (R2), F1                // F1 = im[i]
	FMOVS (R3), F2                // F2 = cosW[i]
	FMOVS (R4), F3                // F3 = sinW[i]
	FMOVS (R5), F4                // F4 = decay[i]

	FMULS F0, F2, F5              // F5 = re * cosW
	FMULS F1, F3, F6              // F6 = im * sinW
	FSUBS F6, F5, F5              // F5 = re*cosW - im*sinW

	FMULS F0, F3, F7              // F7 = re * sinW
	FMULS F1, F2, F6              // F6 = im * cosW
	FADDS F6, F7, F7              // F7 = re*sinW + im*cosW

	FMULS F4, F5, F5              // F5 = decay * newRe
	FMULS F4, F7, F7              // F7 = decay * newIm

	FMOVS F5, (R1)               // Store re
	FMOVS F7, (R2)               // Store im

	// dst[i] += gain[i] * re[i]
	FMOVS (R6), F8                // F8 = gain[i]
	FMULS F5, F8, F8              // F8 = gain * newRe
	FMOVS (R0), F9                // F9 = dst[i]
	FADDS F8, F9, F9              // F9 = dst + gain * newRe
	FMOVS F9, (R0)               // Store dst

	ADD  $4, R0
	ADD  $4, R1
	ADD  $4, R2
	ADD  $4, R3
	ADD  $4, R4
	ADD  $4, R5
	ADD  $4, R6
	SUBS $1, R7
	BNE  rdaf32n_scalar

rdaf32n_done:
	RET
