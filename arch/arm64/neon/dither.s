//go:build !purego && arm64

#include "textflag.h"

// TPDF dither using circular buffer PRNG with additive feedback.
// ARM64 implementation: scalar PRNG with SCVTF conversion.
//
// PRNG per sample (sequential, matches generic Go reference):
//   Average 1: read field[pos], shift>>1, feedback to field[(pos-1)&63], pos=(pos+2)&63
//   Average 2: read field[pos], shift>>1, feedback to field[(pos-1)&63], pos=(pos+2)&63
//   sum = shifted1 + shifted2

// func generateTPDFNEON(dst []float64, scale float64, field *[64]uint32, pos int) int
TEXT ·generateTPDFNEON(SB), NOSPLIT, $0-56
	MOVD  dst_base+0(FP), R0   // R0 = dst pointer
	MOVD  dst_len+8(FP), R3    // R3 = len(dst)
	FMOVD scale+24(FP), F7     // F7 = scale
	MOVD  field+32(FP), R1     // R1 = field pointer
	MOVD  pos+40(FP), R2       // R2 = pos

gen_loop:
	// --- Average 1 ---
	LSL  $2, R2, R4            // R4 = pos * 4
	MOVW (R1)(R4), R5          // R5 = field[pos] (uint32)
	ASRW $1, R5, R6            // R6 = int32(val) >> 1 (sum starts here)

	// Feedback: field[(pos-1)&63] += val
	SUB  $1, R2, R7            // R7 = pos - 1
	AND  $63, R7               // R7 = (pos-1) & 63
	LSL  $2, R7, R8            // R8 = byte offset
	MOVW (R1)(R8), R9          // R9 = field[(pos-1)&63]
	ADDW R5, R9                // R9 += val
	MOVW R9, (R1)(R8)          // store back

	// Advance pos
	ADD  $2, R2
	AND  $63, R2

	// --- Average 2 ---
	LSL  $2, R2, R4
	MOVW (R1)(R4), R5
	ASRW $1, R5, R7            // R7 = shifted
	ADDW R7, R6                // sum += shifted2

	SUB  $1, R2, R7
	AND  $63, R7
	LSL  $2, R7, R8
	MOVW (R1)(R8), R9
	ADDW R5, R9
	MOVW R9, (R1)(R8)

	ADD  $2, R2
	AND  $63, R2

	// --- Convert sum to float64, scale, store ---
	SCVTFWS R6, F0             // F0 = float64(int32 sum)
	FMULD   F7, F0, F0         // F0 *= scale
	FMOVD   F0, (R0)           // store
	ADD     $8, R0

	SUBS $1, R3
	BNE  gen_loop

	MOVD R2, ret+48(FP)
	RET


// func addDitherTPDFNEON(dst []float64, scale float64, field *[64]uint32, pos int) int
TEXT ·addDitherTPDFNEON(SB), NOSPLIT, $0-56
	MOVD  dst_base+0(FP), R0
	MOVD  dst_len+8(FP), R3
	FMOVD scale+24(FP), F7
	MOVD  field+32(FP), R1
	MOVD  pos+40(FP), R2

add_loop:
	// --- Average 1 ---
	LSL  $2, R2, R4
	MOVW (R1)(R4), R5
	ASRW $1, R5, R6

	SUB  $1, R2, R7
	AND  $63, R7
	LSL  $2, R7, R8
	MOVW (R1)(R8), R9
	ADDW R5, R9
	MOVW R9, (R1)(R8)

	ADD  $2, R2
	AND  $63, R2

	// --- Average 2 ---
	LSL  $2, R2, R4
	MOVW (R1)(R4), R5
	ASRW $1, R5, R7
	ADDW R7, R6

	SUB  $1, R2, R7
	AND  $63, R7
	LSL  $2, R7, R8
	MOVW (R1)(R8), R9
	ADDW R5, R9
	MOVW R9, (R1)(R8)

	ADD  $2, R2
	AND  $63, R2

	// --- Convert, scale, ADD to dst ---
	SCVTFWS R6, F0
	FMULD   F7, F0, F0
	FMOVD   (R0), F1           // load existing dst
	FADDD   F1, F0, F0         // add dither
	FMOVD   F0, (R0)
	ADD     $8, R0

	SUBS $1, R3
	BNE  add_loop

	MOVD R2, ret+48(FP)
	RET
