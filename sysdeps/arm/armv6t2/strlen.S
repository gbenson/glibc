/* Copyright (C) 2010-2015 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <http://www.gnu.org/licenses/>.  */

/*
   Assumes:
   ARMv6T2, AArch32

 */

#include <arm-features.h>               /* This might #define NO_THUMB.  */
#include <sysdep.h>

#ifdef __ARMEB__
#define S2LO		lsl
#define S2HI		lsr
#else
#define S2LO		lsr
#define S2HI		lsl
#endif

#ifndef NO_THUMB
/* This code is best on Thumb.  */
	.thumb
#else
/* Using bne.w explicitly is desirable in Thumb mode because it helps
   align the following label without a nop.  In ARM mode there is no
   such difference.  */
.macro bne.w label
	bne \label
.endm

/* This clobbers the condition codes, which the real Thumb cbnz instruction
   does not do.  But it doesn't matter for any of the uses here.  */
.macro cbnz reg, label
	cmp \reg, #0
	bne \label
.endm
#endif

/* Parameters and result.  */
#define srcin		r0
#define result		r0

/* Internal variables.  */
#define src		r1
#define data1a		r2
#define data1b		r3
#define const_m1	r12
#define const_0		r4
#define tmp1		r4		/* Overlaps const_0  */
#define tmp2		r5

	.text
	.p2align 6
ENTRY(strlen)
	sfi_pld	srcin, #0
	strd	r4, r5, [sp, #-8]!
	cfi_adjust_cfa_offset (8)
	cfi_rel_offset (r4, 0)
	cfi_rel_offset (r5, 4)
	cfi_remember_state
	bic	src, srcin, #7
	mvn	const_m1, #0
	ands	tmp1, srcin, #7		/* (8 - bytes) to alignment.  */
	sfi_pld	src, #32
	bne.w	.Lmisaligned8
	mov	const_0, #0
	mov	result, #-8
.Lloop_aligned:
	/* Bytes 0-7.  */
	sfi_breg src, \
	ldrd	data1a, data1b, [\B]
	sfi_pld	src, #64
	add	result, result, #8
.Lstart_realigned:
	uadd8	data1a, data1a, const_m1	/* Saturating GE<0:3> set.  */
	sel	data1a, const_0, const_m1	/* Select based on GE<0:3>.  */
	uadd8	data1b, data1b, const_m1
	sel	data1b, data1a, const_m1	/* Only used if d1a == 0.  */
	cbnz	data1b, .Lnull_found

	/* Bytes 8-15.  */
	sfi_breg src, \
	ldrd	data1a, data1b, [\B, #8]
	uadd8	data1a, data1a, const_m1	/* Saturating GE<0:3> set.  */
	add	result, result, #8
	sel	data1a, const_0, const_m1	/* Select based on GE<0:3>.  */
	uadd8	data1b, data1b, const_m1
	sel	data1b, data1a, const_m1	/* Only used if d1a == 0.  */
	cbnz	data1b, .Lnull_found

	/* Bytes 16-23.  */
	sfi_breg src, \
	ldrd	data1a, data1b, [\B, #16]
	uadd8	data1a, data1a, const_m1	/* Saturating GE<0:3> set.  */
	add	result, result, #8
	sel	data1a, const_0, const_m1	/* Select based on GE<0:3>.  */
	uadd8	data1b, data1b, const_m1
	sel	data1b, data1a, const_m1	/* Only used if d1a == 0.  */
	cbnz	data1b, .Lnull_found

	/* Bytes 24-31.  */
	sfi_breg src, \
	ldrd	data1a, data1b, [\B, #24]
	add	src, src, #32
	uadd8	data1a, data1a, const_m1	/* Saturating GE<0:3> set.  */
	add	result, result, #8
	sel	data1a, const_0, const_m1	/* Select based on GE<0:3>.  */
	uadd8	data1b, data1b, const_m1
	sel	data1b, data1a, const_m1	/* Only used if d1a == 0.  */
	cmp	data1b, #0
	beq	.Lloop_aligned

.Lnull_found:
	cmp	data1a, #0
	itt	eq
	addeq	result, result, #4
	moveq	data1a, data1b
#ifndef __ARMEB__
	rev	data1a, data1a
#endif
	clz	data1a, data1a
	ldrd	r4, r5, [sp], #8
	cfi_adjust_cfa_offset (-8)
	cfi_restore (r4)
	cfi_restore (r5)
	add	result, result, data1a, lsr #3	/* Bits -> Bytes.  */
	DO_RET(lr)

.Lmisaligned8:
	cfi_restore_state
	sfi_breg src, \
	ldrd	data1a, data1b, [\B]
	and	tmp2, tmp1, #3
	rsb	result, tmp1, #0
	lsl	tmp2, tmp2, #3			/* Bytes -> bits.  */
	tst	tmp1, #4
	sfi_pld	src, #64
	S2HI	tmp2, const_m1, tmp2
#ifdef NO_THUMB
	mvn	tmp1, tmp2
	orr	data1a, data1a, tmp1
	itt	ne
	orrne	data1b, data1b, tmp1
#else
	orn	data1a, data1a, tmp2
	itt	ne
	ornne	data1b, data1b, tmp2
#endif
	movne	data1a, const_m1
	mov	const_0, #0
	b	.Lstart_realigned

END(strlen)
libc_hidden_builtin_def (strlen)
