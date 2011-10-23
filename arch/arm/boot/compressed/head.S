/*
 *  linux/arch/arm/boot/compressed/head.S
 *
 *  Copyright (C) 1996-2002 Russell King
 *  Copyright (C) 2004 Hyok S. Choi (MPU support)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */
#include <linux/linkage.h>

/*
 * Debugging stuff
 *
 * Note that these macros must not contain any code which is not
 * 100% relocatable.  Any attempt to do so will result in a crash.
 * Please select one of the following when turning on debugging.
 */
@ 디버깅용 코드는 100% 재배치하게 해야하며, 그렇지 않으면 망가짐.
#ifdef DEBUG

#if defined(CONFIG_DEBUG_ICEDCC)

@ loadsp - 아무 것 하지 않음.
@ writeb (ch, rb) - DBGDTRTXint - 타겟에서 호스트로 기록
#if defined(CONFIG_CPU_V6) || defined(CONFIG_CPU_V6K) || defined(CONFIG_CPU_V7)
		.macro	loadsp, rb, tmp
		.endm
		.macro	writeb, ch, rb
		mcr	p14, 0, \ch, c0, c5, 0
		.endm
#elif defined(CONFIG_CPU_XSCALE)
		.macro	loadsp, rb, tmp
		.endm
		.macro	writeb, ch, rb
		mcr	p14, 0, \ch, c8, c0, 0
		.endm
#else
		.macro	loadsp, rb, tmp
		.endm
		.macro	writeb, ch, rb
		mcr	p14, 0, \ch, c1, c0, 0
		.endm
#endif


#else

#include <mach/debug-macro.S>

@ 디버그 모드가 아니면 debug-macro.S의 senduart로 writeb를 구현한다.
@ 우리가 봐야할 mach-exynos4/include/mach/debug-macro.S에는
@ senduart의 구현이 없다. 해당 내용은 plat-samsung/include/plat에
@ 위치한다.
@ 삼성은 장기적으로 하나의 플랫폼 디렉터리(plat-samsung)과 개별 칩을 다루는
@ 머신(mach-)로 분류한다.
@ see also: http://comments.gmane.org/gmane.linux.kernel.samsung-soc/7143

@ writeb (ch, rb) - strb ch, [rb, #S3C2410_UTXH]로 호출
@ #S3C2410_UTXH는 0x20 - 동 디렉토리의 regs-serial.h
		.macro	writeb,	ch, rb
		senduart \ch, \rb
		.endm

#if defined(CONFIG_ARCH_SA1100)
		.macro	loadsp, rb, tmp
		mov	\rb, #0x80000000	@ physical base address
#ifdef CONFIG_DEBUG_LL_SER3
		add	\rb, \rb, #0x00050000	@ Ser3
#else
		add	\rb, \rb, #0x00010000	@ Ser1
#endif
		.endm
#elif defined(CONFIG_ARCH_S3C2410)
		.macro loadsp, rb, tmp
		mov	\rb, #0x50000000
		add	\rb, \rb, #0x4000 * CONFIG_S3C_LOWLEVEL_UART_PORT
		.endm
#else

@ loadsp는 adduart 호출. (mach-exynos/include/mach/debug-macro.S에 위치)
@ 0x100000 * CONFIG_DEBUG_S3C_UART를 #S3C_PA_UART와 #S3C_VA_UART에 더해서 rb와 tmp에 넣음.
@ PA UART는 0x13800000, VA UART는 0XF6000000 + 0x01000000(plat에 위치)
@ 인자가 사실은 리턴값.

		.macro	loadsp,	rb, tmp
		addruart \rb, \tmp
		.endm
#endif
#endif
#endif

		.macro	kputc,val
		mov	r0, \val
		bl	putc
		.endm

		.macro	kphex,val,len
		mov	r0, \val
		mov	r1, #\len
		bl	phex
		.endm

		.macro	debug_reloc_start
#ifdef DEBUG
		kputc	#'\n'
		kphex	r6, 8		/* processor id */
		kputc	#':'
		kphex	r7, 8		/* architecture id */
#ifdef CONFIG_CPU_CP15
		kputc	#':'
		mrc	p15, 0, r0, c1, c0
		kphex	r0, 8		/* control reg */
#endif
		kputc	#'\n'
		kphex	r5, 8		/* decompressed kernel start */
		kputc	#'-'
		kphex	r9, 8		/* decompressed kernel end  */
		kputc	#'>'
		kphex	r4, 8		/* kernel execution address */
		kputc	#'\n'
#endif
		.endm

		.macro	debug_reloc_end
#ifdef DEBUG
		kphex	r5, 8		/* end of kernel */
		kputc	#'\n'
		mov	r0, r4
		bl	memdump		/* dump 256 bytes at start of kernel */
#endif
		.endm

/* iamroot : .section은 새로운 section을 정의하는 것이다.
   #alloc은 allocatable을 의미하고 #execinstr은 executable을 의미한다.
 */
		.section ".start", #alloc, #execinstr
/*
 * sort out different calling conventions
 */
                              @ arm에서는 .align 직후의 값이 생략될 수 있으며 (PC에선 안됨)
                              @ 0이면 2가 입력된 것처럼 작동된다. (0이면, 2^2 = 4)
                              @ 두번째 값은 채울 값, 세번째 값은 최대값이다.
                              @ .align이 입력된 순간 0~3바이트의 패딩이 입력되어 정렬이 된다.
		.align
		.arm				@ Always enter in ARM state
                              @사실상 .arm은 .code 32로 처리되고 .thumb는 .code 16으로 처리 된다.

    /* iamroot : start를 function이라고 지정한다.
       GNU assembler directive : http://sources.redhat.com/binutils/docs-2.12/as.info/Pseudo-Ops.html#Pseudo%20Ops
       mov r0, r0 : http://www.iamroot.org/xe/index.php?mid=QnA&page=7&document_srl=23099 댓글 확인
     */

                              @ ARM과 THUMB은 C언어의 전처리기로 만들어졌다.
                              @ arch/arm/include/asm/unified.h에 위치. 링크를 하는 위치는 /Makefile에서
                              @ 어셈의 플래그로 설정.

start:
		.type	start,#function
		.rept	7
		mov	r0, r0
		.endr
   ARM(		mov	r0, r0		)
   ARM(		b	1f		)
 THUMB(		adr	r12, BSYM(1f)	)           /* iamroot : BSYM = 맨마지막 bit를 1로 바꿔 준다.(arch/arm/include/asm/unified.h) */
 THUMB(		bx	r12		)
		.word	0x016f2818		@ Magic numbers to help the loader
		.word	start			@ absolute load/run zImage address
		.word	_edata			@ zImage end address
 THUMB(		.thumb			)
1:		mov	r7, r1			@ save architecture ID
		mov	r8, r2			@ save atags pointer

#ifndef __ARM_ARCH_2__
		/*
		 * Booting from Angel - need to enter SVC mode and disable
		 * FIQs/IRQs (numeric definitions from angel arm.h source).
		 * We only do this if we were in user mode on entry.
		 */
		mrs	r2, cpsr		@ get current mode

    /* iamroot : tst의 결과가 1이면 zflag가 0된다.)
       Angel은 ARM 디버거와 통신하는 타겟에서 돌고 있는 디버깅용 모니터 프로그램이다. */

		tst	r2, #3			@ not user?
                                                @ 하위 2비트가 모두 0이면 user 모드이다.
		bne	not_angel               @ Z clear == not equal
		mov	r0, #0x17		@ angel_SWIreason_EnterSVC
 ARM(		swi	0x123456	)	@ angel_SWI_ARM
 THUMB(		svc	0xab		)	@ angel_SWI_THUMB
not_angel:
		mrs	r2, cpsr		@ turn off interrupts to
		orr	r2, r2, #0xc0		@ prevent angel from running
                                                @ IRC 및 FIQ 인터럽트를 끈다.
		msr	cpsr_c, r2      /* iamroot : _c의 의미는 NZCV condition flags 를 변경하지 않겠다. */
#else
		teqp	pc, #0x0c000003		@ turn off interrupts     @teqp = xor
#endif

		/*
		 * Note that some cache flushing and other stuff may
		 * be needed here - is there an Angel SWI call for this?
		 */

		/*
		 * some architecture specific code can be inserted
		 * by the linker here, but it should preserve r7, r8, and r9.
		 */

		.text

    /* iamroot : TEXT_OFFSET의 값은 -> arch/arm/Makefile?
       ZRELADDR : 압축이 해제된 커널이 놓일 주소이다.
       r4에는 text의 위치가 입력된다. */

  @ ZRELADDR도 arcm/arm/Makefile에서 설정되는데 실제 값은 mach-exynos4/Makefile.boot
  @ 의 zreladdr-y의 값에 의해 결정되고 0x40000000이다.

  @ #TEXT_OFFSET의 값도 실제로는 textofs-y에 의해 결정되지만 외부 파일에 의존하지 않고
  @ Makefile에 의해서만 결정된다. 아키텍쳐에 따라 다른 주소를 가지도록 상위 Makefile에 하드코딩되어있다.
  @ 기본값으로 0x00008000이며 몇몇 지정된 칩의 경우 값 변경.

    @  r4 = kernel execution address
#ifdef CONFIG_AUTO_ZRELADDR
		@ determine final kernel image address
		mov	r4, pc                  @ 실행시점에 pc = 현위치 + 8byte
		and	r4, r4, #0xf8000000  @앞에 5비트를 가지고 온다.
                add     r4, r4, #TEXT_OFFSET
#else
		ldr	r4, =zreladdr
#endif

		bl	cache_on      /* iamroot : lr을 저장하고 branch하라. */

restart:	adr	r0, LC0
		ldmia	r0, {r1, r2, r3, r6, r10, r11, r12}
		ldr	sp, [r0, #28]

		/*
		 * We might be running at a different address.  We need
		 * to fix up various pointers.
		 */
		sub	r0, r0, r1		@ calculate the delta offset
		add	r6, r6, r0		@ _edata
		add	r10, r10, r0		@ inflated kernel size location

		/*
		 * The kernel build system appends the size of the
		 * decompressed kernel at the end of the compressed data
		 * in little-endian form.
		 */
		ldrb	r9, [r10, #0]
		ldrb	lr, [r10, #1]
		orr	r9, r9, lr, lsl #8
		ldrb	lr, [r10, #2]
		ldrb	r10, [r10, #3]
		orr	r9, r9, lr, lsl #16
		orr	r9, r9, r10, lsl #24

#ifndef CONFIG_ZBOOT_ROM
		/* malloc space is above the relocated stack (64k max) */
		add	sp, sp, r0
		add	r10, sp, #0x10000
#else
		/*
		 * With ZBOOT_ROM the bss/stack is non relocatable,
		 * but someone could still run this code from RAM,
		 * in which case our reference is _edata.
		 */
		mov	r10, r6
#endif

/*
 * Check to see if we will overwrite ourselves.
 *   r4  = final kernel address
 *   r9  = size of decompressed image
 *   r10 = end of this image, including  bss/stack/malloc space if non XIP
 * We basically want:
 *   r4 - 16k page directory >= r10 -> OK
 *   r4 + image length <= current position (pc) -> OK
 */
		add	r10, r10, #16384
		cmp	r4, r10
		bhs	wont_overwrite
		add	r10, r4, r9
   ARM(		cmp	r10, pc		)
 THUMB(		mov	lr, pc		)
 THUMB(		cmp	r10, lr		)
		bls	wont_overwrite

/*
 * Relocate ourselves past the end of the decompressed kernel.
 *   r6  = _edata
 *   r10 = end of the decompressed kernel
 * Because we always copy ahead, we need to do it from the end and go
 * backward in case the source and destination overlap.
 */
		/*
		 * Bump to the next 256-byte boundary with the size of
		 * the relocation code added. This avoids overwriting
		 * ourself when the offset is small.
		 */
		add	r10, r10, #((reloc_code_end - restart + 256) & ~255)
		bic	r10, r10, #255

		/* Get start of code we want to copy and align it down. */
		adr	r5, restart
		bic	r5, r5, #31

		sub	r9, r6, r5		@ size to copy
		add	r9, r9, #31		@ rounded up to a multiple
		bic	r9, r9, #31		@ ... of 32 bytes
		add	r6, r9, r5
		add	r9, r9, r10

1:		ldmdb	r6!, {r0 - r3, r10 - r12, lr}
		cmp	r6, r5
		stmdb	r9!, {r0 - r3, r10 - r12, lr}
		bhi	1b

		/* Preserve offset to relocated code. */
		sub	r6, r9, r6

#ifndef CONFIG_ZBOOT_ROM
		/* cache_clean_flush may use the stack, so relocate it */
		add	sp, sp, r6
#endif

		bl	cache_clean_flush

		adr	r0, BSYM(restart)
		add	r0, r0, r6
		mov	pc, r0

wont_overwrite:
/*
 * If delta is zero, we are running at the address we were linked at.
 *   r0  = delta
 *   r2  = BSS start
 *   r3  = BSS end
 *   r4  = kernel execution address
 *   r7  = architecture ID
 *   r8  = atags pointer
 *   r11 = GOT start
 *   r12 = GOT end
 *   sp  = stack pointer
 */
		teq	r0, #0
		beq	not_relocated
		add	r11, r11, r0
		add	r12, r12, r0

#ifndef CONFIG_ZBOOT_ROM
		/*
		 * If we're running fully PIC === CONFIG_ZBOOT_ROM = n,
		 * we need to fix up pointers into the BSS region.
		 * Note that the stack pointer has already been fixed up.
		 */
		add	r2, r2, r0
		add	r3, r3, r0

		/*
		 * Relocate all entries in the GOT table.
		 */
1:		ldr	r1, [r11, #0]		@ relocate entries in the GOT
		add	r1, r1, r0		@ table.  This fixes up the
		str	r1, [r11], #4		@ C references.
		cmp	r11, r12
		blo	1b
#else

		/*
		 * Relocate entries in the GOT table.  We only relocate
		 * the entries that are outside the (relocated) BSS region.
		 */
1:		ldr	r1, [r11, #0]		@ relocate entries in the GOT
		cmp	r1, r2			@ entry < bss_start ||
		cmphs	r3, r1			@ _end < entry
		addlo	r1, r1, r0		@ table.  This fixes up the
		str	r1, [r11], #4		@ C references.
		cmp	r11, r12
		blo	1b
#endif

not_relocated:	mov	r0, #0
1:		str	r0, [r2], #4		@ clear bss
		str	r0, [r2], #4
		str	r0, [r2], #4
		str	r0, [r2], #4
		cmp	r2, r3
		blo	1b

/*
 * The C runtime environment should now be setup sufficiently.
 * Set up some pointers, and start decompressing.
 *   r4  = kernel execution address
 *   r7  = architecture ID
 *   r8  = atags pointer
 */
		mov	r0, r4
		mov	r1, sp			@ malloc space above stack
		add	r2, sp, #0x10000	@ 64k max
		mov	r3, r7
		bl	decompress_kernel
		bl	cache_clean_flush
		bl	cache_off
		mov	r0, #0			@ must be zero
		mov	r1, r7			@ restore architecture number
		mov	r2, r8			@ restore atags pointer
 ARM(		mov	pc, r4	)		@ call kernel
 THUMB(		bx	r4	)		@ entry point is always ARM

		.align	2
		.type	LC0, #object
@ Literal Constant 인것같다.
LC0:		.word	LC0			@ r1
		.word	__bss_start		@ r2
		.word	_end			@ r3
		.word	_edata			@ r6
		.word	input_data_end - 4	@ r10 (inflated size location)
		.word	_got_start		@ r11
		.word	_got_end		@ ip
		.word	.L_user_stack_end	@ sp
		.size	LC0, . - LC0

#ifdef CONFIG_ARCH_RPC
		.globl	params
params:		ldr	r0, =0x10000100		@ params_phys for RPC
		mov	pc, lr
		.ltorg
		.align
#endif

/*
 * Turn on the cache.  We need to setup some page tables so that we
 * can have both the I and D caches on.
 *
 * We place the page tables 16k down from the kernel execution address,
 * and we hope that nothing else is using it.  If we're using it, we
 * will go pop!
 *
 * On entry,
 *  r4 = kernel execution address
 *  r7 = architecture number
 *  r8 = atags pointer
 * On exit,
 *  r0, r1, r2, r3, r9, r10, r12 corrupted
 * This routine must preserve:
 *  r4, r7, r8
 */
		.align	5
                              @ 2^5 = 32. 0~31바이트의 공백을 두어서 정렬을
                              @ 시키는 것을 의미함.
cache_on:	mov	r3, #8			@ cache_on function
		b	call_cache_fn

/*
 * Initialize the highest priority protection region, PR7
 * to cover all 32bit address and cacheable and bufferable.
 */
__armv4_mpu_cache_on:
		mov	r0, #0x3f		@ 4G, the whole
		mcr	p15, 0, r0, c6, c7, 0	@ PR7 Area Setting
		mcr 	p15, 0, r0, c6, c7, 1

		mov	r0, #0x80		@ PR7
		mcr	p15, 0, r0, c2, c0, 0	@ D-cache on
		mcr	p15, 0, r0, c2, c0, 1	@ I-cache on
		mcr	p15, 0, r0, c3, c0, 0	@ write-buffer on

		mov	r0, #0xc000
		mcr	p15, 0, r0, c5, c0, 1	@ I-access permission
		mcr	p15, 0, r0, c5, c0, 0	@ D-access permission

		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c7, c5, 0	@ flush(inval) I-Cache
		mcr	p15, 0, r0, c7, c6, 0	@ flush(inval) D-Cache
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
						@ ...I .... ..D. WC.M
		orr	r0, r0, #0x002d		@ .... .... ..1. 11.1
		orr	r0, r0, #0x1000		@ ...1 .... .... ....

		mcr	p15, 0, r0, c1, c0, 0	@ write control reg

		mov	r0, #0
		mcr	p15, 0, r0, c7, c5, 0	@ flush(inval) I-Cache
		mcr	p15, 0, r0, c7, c6, 0	@ flush(inval) D-Cache
		mov	pc, lr

__armv3_mpu_cache_on:
		mov	r0, #0x3f		@ 4G, the whole
		mcr	p15, 0, r0, c6, c7, 0	@ PR7 Area Setting

		mov	r0, #0x80		@ PR7
		mcr	p15, 0, r0, c2, c0, 0	@ cache on
		mcr	p15, 0, r0, c3, c0, 0	@ write-buffer on

		mov	r0, #0xc000
		mcr	p15, 0, r0, c5, c0, 0	@ access permission

		mov	r0, #0
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		/*
		 * ?? ARMv3 MMU does not allow reading the control register,
		 * does this really work on ARMv3 MPU?
		 */
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
						@ .... .... .... WC.M
		orr	r0, r0, #0x000d		@ .... .... .... 11.1
		/* ?? this overwrites the value constructed above? */
		mov	r0, #0
		mcr	p15, 0, r0, c1, c0, 0	@ write control reg

		/* ?? invalidate for the second time? */
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		mov	pc, lr

        @ r4 = zImage (0x40008000)
        @ r3 = page directory address

__setup_mmu:	sub	r3, r4, #16384		@ Page directory size (2^14)
		bic	r3, r3, #0xff		@ Align the pointer
		bic	r3, r3, #0x3f00
/*
 * Initialise the page tables, turning on the cacheable and bufferable
 * bits for the RAM area only.
 */

        @ r0 = r3 = page directory address
        @ r9 = start of RAM

		mov	r0, r3                  @ r0=0x40004000
		mov	r9, r0, lsr #18         @ 하위에 18비트를 클리어 
		mov	r9, r9, lsl #18		@ start of RAM (0x40000000)

        @ r10 = reasonable(?) end of RAM

		add	r10, r9, #0x10000000	@ a reasonable RAM size (256M)

        @ r1 = 0xc12

		mov	r1, #0x12
		orr	r1, r1, #3 << 10        @ 다시 커널 이미지 어드레스

        @ r2 = zImage (need patch)

		add	r2, r3, #16384          @ 2^14

        @

1:		cmp	r1, r9			@ if virt > start of RAM
#ifdef CONFIG_CPU_DCACHE_WRITETHROUGH
		orrhs	r1, r1, #0x08		@ set cacheable
#else
		orrhs	r1, r1, #0x0c		@ set cacheable, bufferable
#endif

        @ r10 = reasonable(?) end of RAM
        @ r2 = zImage (need patch)
        @ r1 = 0xc12
        @ r0 = r3 = page directory address

		cmp	r1, r10			@ if virt > end of RAM
		bichs	r1, r1, #0x0c		@ clear cacheable, bufferable
		str	r1, [r0], #4		@ 1:1 mapping
		add	r1, r1, #1048576	@(1M) mmu page size 를 1M씩 활당
		teq	r0, r2
		bne	1b

 @ 램에만 cachable / bufferable 플래그를 설정한다.
        
/*
 *   
 *  +--------------+ <- 0x4000.0000
 *  |              |
 *  |              | 
 *  |              |
 *  +--------------+ <- 0x4000.4000
 *  |              |
 *  | page direct  | 
 *  |              |
 *  +--------------+ <- 0x4000.8000
 *  | zImage       |
 *  +--------------+
 *  |              |
 *  |              |
 *  |              |
 *  |              |
 *  |              |
 *  |              |
 *  |              |
 *  +--------------+
 *
16kb / 4byte

1024 * 16 byte / 4byte

1024 * 4 byte

4096 개
 *
 * machine cortex A9 <--> exynos4210 
 */
        
/*
 * If ever we are running from Flash, then we surely want the cache
 * to be enabled also for our execution instance...  We map 2MB of it
 * so there is no map overlap problem for up to 1 MB compressed kernel.
 * If the execution is in RAM then we would only be duplicating the above.
 */

        @ r3 = page directory address
        @ pc에서 시작하는 이유는 2MB 커널에서 사용하기 위한 페이지 테이블이기 때문
        
		mov	r1, #0x1e             @ enable cacheable + bufferable
		orr	r1, r1, #3 << 10      @ r1 = 0xc1e
		mov	r2, pc                @ 
		mov	r2, r2, lsr #20       @ 
		orr	r1, r1, r2, lsl #20   @ r1 |= pc  clr  20bit
		add	r0, r3, r2, lsl #2    @ 
		str	r1, [r0], #4
		add	r1, r1, #1048576
		str	r1, [r0]
		mov	pc, lr
ENDPROC(__setup_mmu)

__arm926ejs_mmu_cache_on:
#ifdef CONFIG_CPU_DCACHE_WRITETHROUGH
		mov	r0, #4			@ put dcache in WT mode
		mcr	p15, 7, r0, c15, c0, 0
#endif

__armv4_mmu_cache_on:
		mov	r12, lr
#ifdef CONFIG_MMU
		bl	__setup_mmu
		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c8, c7, 0	@ flush I,D TLBs
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
		orr	r0, r0, #0x5000		@ I-cache enable, RR cache replacement
		orr	r0, r0, #0x0030
#ifdef CONFIG_CPU_ENDIAN_BE8
		orr	r0, r0, #1 << 25	@ big-endian page tables
#endif
		bl	__common_mmu_cache_on
		mov	r0, #0
		mcr	p15, 0, r0, c8, c7, 0	@ flush I,D TLBs
#endif
		mov	pc, r12

__armv7_mmu_cache_on:
		mov	r12, lr
#ifdef CONFIG_MMU

    /*iamroot mrc	p15, 0, r11, c0, c1, 4
      c0:major(CRn), c1:minor(CRm), op1=0, op2=4
      ddi0388g_cortex_a9_r3p0_trm.pdf에서 일단 c0으로 4.2.1장 c0 register를 찾으며
      나머지 op1, c1, op2를 이용하여 Memory Model Feature Register0이라는 것을 알 수 있다. */

		mrc	p15, 0, r11, c0, c1, 4	@ read ID_MMFR0   @iamroot:Memory Model Feature Register0
		tst	r11, #0xf		@ VMSA            @iamroot:Virtual Memory System Archiecture
		blne	__setup_mmu
		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		tst	r11, #0xf		@ VMSA
		mcrne	p15, 0, r0, c8, c7, 0	@ flush I,D TLBs
#endif
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
		orr	r0, r0, #0x5000		@ I-cache enable, RR cache replacement
		orr	r0, r0, #0x003c		@ write buffer
#ifdef CONFIG_MMU
#ifdef CONFIG_CPU_ENDIAN_BE8
		orr	r0, r0, #1 << 25	@ big-endian page tables
#endif
		orrne	r0, r0, #1		@ MMU enabled
		movne	r1, #-1
		mcrne	p15, 0, r3, c2, c0, 0	@ load page table pointer
		mcrne	p15, 0, r1, c3, c0, 0	@ load domain access control
#endif
		mcr	p15, 0, r0, c1, c0, 0	@ load control register
		mrc	p15, 0, r0, c1, c0, 0	@ and read it back
		mov	r0, #0
		mcr	p15, 0, r0, c7, c5, 4	@ ISB
		mov	pc, r12

__fa526_cache_on:
		mov	r12, lr
		bl	__setup_mmu
		mov	r0, #0
		mcr	p15, 0, r0, c7, c7, 0	@ Invalidate whole cache
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c8, c7, 0	@ flush UTLB
		mrc	p15, 0, r0, c1, c0, 0	@ read control reg
		orr	r0, r0, #0x1000		@ I-cache enable
		bl	__common_mmu_cache_on
		mov	r0, #0
		mcr	p15, 0, r0, c8, c7, 0	@ flush UTLB
		mov	pc, r12

__arm6_mmu_cache_on:
		mov	r12, lr
		bl	__setup_mmu
		mov	r0, #0
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		mcr	p15, 0, r0, c5, c0, 0	@ invalidate whole TLB v3
		mov	r0, #0x30
		bl	__common_mmu_cache_on
		mov	r0, #0
		mcr	p15, 0, r0, c5, c0, 0	@ invalidate whole TLB v3
		mov	pc, r12

__common_mmu_cache_on:
#ifndef CONFIG_THUMB2_KERNEL
#ifndef DEBUG
		orr	r0, r0, #0x000d		@ Write buffer, mmu
#endif
		mov	r1, #-1
		mcr	p15, 0, r3, c2, c0, 0	@ load page table pointer
		mcr	p15, 0, r1, c3, c0, 0	@ load domain access control
		b	1f
		.align	5			@ cache line aligned
1:		mcr	p15, 0, r0, c1, c0, 0	@ load control register
		mrc	p15, 0, r0, c1, c0, 0	@ and read it back to
		sub	pc, lr, r0, lsr #32	@ properly flush pipeline
#endif

#define PROC_ENTRY_SIZE (4*5)

/*
 * Here follow the relocatable cache support functions for the
 * various processors.  This is a generic hook for locating an
 * entry and jumping to an instruction at the specified offset
 * from the start of the block.  Please note this is all position
 * independent code.
 *
 *  r1  = corrupted
 *  r2  = corrupted
 *  r3  = block offset
 *  r9  = corrupted
 *  r12 = corrupted
 */

                              @f3은 8로 들어왔음.
call_cache_fn:	adr	r12, proc_types

/* iamroot : 같은 processor ID를 loop를 돌아 찾는다. new CPU ID라고 아래에 선언되어 있다.
   __armv7_mmu_cache_on, __armv7_mmu_cache_off, __armv7_mmu_cache_flush */

#ifdef CONFIG_CPU_CP15
		mrc	p15, 0, r9, c0, c0	@ get processor ID
                              @ 31~24 구현자(ARM:0x41)
                              @ 23~20 CPU 메이저 리비전 (ig. 0x3)
                              @ 19~16 아키텍쳐 (ig. 0xF)
                              @ 15~4 파트 넘버 (ig. Cortex-A8 0xC08)
                              @ 3~0 마이너 리비전 (ig. 0x2)
                              @ 우리가 보는 PC210A칩(엑시노스) 0x43210211?
                              @ User_Guide 4-2페이지의 비트가 다름. -_-
#else
                              @CP15가 없는 칩셋에서는 설정에 넣어줘야 한다.
		ldr	r9, =CONFIG_PROCESSOR_ID
#endif
1:		ldr	r1, [r12, #0]		@ get value
		ldr	r2, [r12, #4]		@ get mask
		eor	r1, r1, r9		@ (real ^ match)
		tst	r1, r2			@       & mask
 ARM(		addeq	pc, r12, r3		) @ call cache function
 THUMB(		addeq	r12, r3			)
 THUMB(		moveq	pc, r12			) @ cal cache function
		add	r12, r12, #PROC_ENTRY_SIZE                         @20
		b	1b
/*
 * Table for cache operations.  This is basically:
 *   - CPU ID match
 *   - CPU ID mask
 *   - 'cache on' method instruction
 *   - 'cache off' method instruction
 *   - 'cache flush' method instruction
 *
 * We match an entry using: ((real_id ^ match) & mask) == 0
 *
 * Writethrough caches generally only need 'on' and 'off'
 * methods.  Writeback caches _must_ have the flush method
 * defined.
 */
		.align	2
		.type	proc_types,#object
proc_types:
		.word	0x41560600		@ ARM6/610
		.word	0xffffffe0

		W(b)	__arm6_mmu_cache_off	@ works, but slow
                             @ W(b) : __ASSEMBLY__로시작하는 게 정의 되어 있으면
                             @ ARM에서는 그냥 들어 있는 명령 그대로, THUMB에서는
                             @ 명령.w로 수행한다.
                             @ .w는 접근 사이즈를 바꾸는 것은 아님. Thumb2를 쓸 때
                             @ 32비트 코드로 작성하라는 것.
    @ see also: http://lists.infradead.org/pipermail/linux-arm-kernel/2009-September/000845.html

		W(b)	__arm6_mmu_cache_off
		mov	pc, lr
 THUMB(		nop				)
@		b	__arm6_mmu_cache_on		@ untested
@		b	__arm6_mmu_cache_off
@		b	__armv3_mmu_cache_flush

		.word	0x00000000		@ old ARM ID
		.word	0x0000f000
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)

		.word	0x41007000		@ ARM7/710
		.word	0xfff8fe00
		W(b)	__arm7_mmu_cache_off
		W(b)	__arm7_mmu_cache_off
		mov	pc, lr
 THUMB(		nop				)

		.word	0x41807200		@ ARM720T (writethrough)
		.word	0xffffff00
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		mov	pc, lr
 THUMB(		nop				)

		.word	0x41007400		@ ARM74x
		.word	0xff00ff00
		W(b)	__armv3_mpu_cache_on
		W(b)	__armv3_mpu_cache_off
		W(b)	__armv3_mpu_cache_flush

		.word	0x41009400		@ ARM94x
		.word	0xff00ff00
		W(b)	__armv4_mpu_cache_on
		W(b)	__armv4_mpu_cache_off
		W(b)	__armv4_mpu_cache_flush

		.word	0x41069260		@ ARM926EJ-S (v5TEJ)
		.word	0xff0ffff0
		W(b)	__arm926ejs_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

		.word	0x00007000		@ ARM7 IDs
		.word	0x0000f000
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)

		@ Everything from here on will be the new ID system.

		.word	0x4401a100		@ sa110 / sa1100
		.word	0xffffffe0
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x6901b110		@ sa1110
		.word	0xfffffff0
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x56056900
		.word	0xffffff00		@ PXA9xx
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x56158000		@ PXA168
		.word	0xfffff000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

		.word	0x56050000		@ Feroceon
		.word	0xff0f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

#ifdef CONFIG_CPU_FEROCEON_OLD_ID
		/* this conflicts with the standard ARMv5TE entry */
		.long	0x41009260		@ Old Feroceon
		.long	0xff00fff0
		b	__armv4_mmu_cache_on
		b	__armv4_mmu_cache_off
		b	__armv5tej_mmu_cache_flush
#endif

		.word	0x66015261		@ FA526
		.word	0xff01fff1
		W(b)	__fa526_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__fa526_cache_flush

		@ These match on the architecture ID

		.word	0x00020000		@ ARMv4T
		.word	0x000f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x00050000		@ ARMv5TE
		.word	0x000f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv4_mmu_cache_flush

		.word	0x00060000		@ ARMv5TEJ
		.word	0x000f0000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv5tej_mmu_cache_flush

		.word	0x0007b000		@ ARMv6
		.word	0x000ff000
		W(b)	__armv4_mmu_cache_on
		W(b)	__armv4_mmu_cache_off
		W(b)	__armv6_mmu_cache_flush

                             @ 여기로 오는 듯?
		.word	0x000f0000		@ new CPU Id
		.word	0x000f0000
		W(b)	__armv7_mmu_cache_on
		W(b)	__armv7_mmu_cache_off
		W(b)	__armv7_mmu_cache_flush

		.word	0			@ unrecognised type
		.word	0
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)
		mov	pc, lr
 THUMB(		nop				)

		.size	proc_types, . - proc_types

		/*
		 * If you get a "non-constant expression in ".if" statement"
		 * error from the assembler on this line, check that you have
		 * not accidentally written a "b" instruction where you should
		 * have written W(b).
		 */
		.if (. - proc_types) % PROC_ENTRY_SIZE != 0
		.error "The size of one or more proc_types entries is wrong."
		.endif

/*
 * Turn off the Cache and MMU.  ARMv3 does not support
 * reading the control register, but ARMv4 does.
 *
 * On exit,
 *  r0, r1, r2, r3, r9, r12 corrupted
 * This routine must preserve:
 *  r4, r7, r8
 */
		.align	5
cache_off:	mov	r3, #12			@ cache_off function
		b	call_cache_fn

__armv4_mpu_cache_off:
		mrc	p15, 0, r0, c1, c0
		bic	r0, r0, #0x000d
		mcr	p15, 0, r0, c1, c0	@ turn MPU and cache off
		mov	r0, #0
		mcr	p15, 0, r0, c7, c10, 4	@ drain write buffer
		mcr	p15, 0, r0, c7, c6, 0	@ flush D-Cache
		mcr	p15, 0, r0, c7, c5, 0	@ flush I-Cache
		mov	pc, lr

__armv3_mpu_cache_off:
		mrc	p15, 0, r0, c1, c0
		bic	r0, r0, #0x000d
		mcr	p15, 0, r0, c1, c0, 0	@ turn MPU and cache off
		mov	r0, #0
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		mov	pc, lr

__armv4_mmu_cache_off:
#ifdef CONFIG_MMU
		mrc	p15, 0, r0, c1, c0
		bic	r0, r0, #0x000d
		mcr	p15, 0, r0, c1, c0	@ turn MMU and cache off
		mov	r0, #0
		mcr	p15, 0, r0, c7, c7	@ invalidate whole cache v4
		mcr	p15, 0, r0, c8, c7	@ invalidate whole TLB v4
#endif
		mov	pc, lr

__armv7_mmu_cache_off:
		mrc	p15, 0, r0, c1, c0
#ifdef CONFIG_MMU
		bic	r0, r0, #0x000d
#else
		bic	r0, r0, #0x000c
#endif
		mcr	p15, 0, r0, c1, c0	@ turn MMU and cache off
		mov	r12, lr
		bl	__armv7_mmu_cache_flush
		mov	r0, #0
#ifdef CONFIG_MMU
		mcr	p15, 0, r0, c8, c7, 0	@ invalidate whole TLB
#endif
		mcr	p15, 0, r0, c7, c5, 6	@ invalidate BTC
		mcr	p15, 0, r0, c7, c10, 4	@ DSB
		mcr	p15, 0, r0, c7, c5, 4	@ ISB
		mov	pc, r12

__arm6_mmu_cache_off:
		mov	r0, #0x00000030		@ ARM6 control reg.
		b	__armv3_mmu_cache_off

__arm7_mmu_cache_off:
		mov	r0, #0x00000070		@ ARM7 control reg.
		b	__armv3_mmu_cache_off

__armv3_mmu_cache_off:
		mcr	p15, 0, r0, c1, c0, 0	@ turn MMU and cache off
		mov	r0, #0
		mcr	p15, 0, r0, c7, c0, 0	@ invalidate whole cache v3
		mcr	p15, 0, r0, c5, c0, 0	@ invalidate whole TLB v3
		mov	pc, lr

/*
 * Clean and flush the cache to maintain consistency.
 *
 * On exit,
 *  r1, r2, r3, r9, r10, r11, r12 corrupted
 * This routine must preserve:
 *  r4, r6, r7, r8
 */
		.align	5
cache_clean_flush:
		mov	r3, #16
		b	call_cache_fn

__armv4_mpu_cache_flush:
		mov	r2, #1
		mov	r3, #0
		mcr	p15, 0, ip, c7, c6, 0	@ invalidate D cache
		mov	r1, #7 << 5		@ 8 segments
1:		orr	r3, r1, #63 << 26	@ 64 entries
2:		mcr	p15, 0, r3, c7, c14, 2	@ clean & invalidate D index
		subs	r3, r3, #1 << 26
		bcs	2b			@ entries 63 to 0
		subs 	r1, r1, #1 << 5
		bcs	1b			@ segments 7 to 0

		teq	r2, #0
		mcrne	p15, 0, ip, c7, c5, 0	@ invalidate I cache
		mcr	p15, 0, ip, c7, c10, 4	@ drain WB
		mov	pc, lr

__fa526_cache_flush:
		mov	r1, #0
		mcr	p15, 0, r1, c7, c14, 0	@ clean and invalidate D cache
		mcr	p15, 0, r1, c7, c5, 0	@ flush I cache
		mcr	p15, 0, r1, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv6_mmu_cache_flush:
		mov	r1, #0
		mcr	p15, 0, r1, c7, c14, 0	@ clean+invalidate D
		mcr	p15, 0, r1, c7, c5, 0	@ invalidate I+BTB
		mcr	p15, 0, r1, c7, c15, 0	@ clean+invalidate unified
		mcr	p15, 0, r1, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv7_mmu_cache_flush:
		mrc	p15, 0, r10, c0, c1, 5	@ read ID_MMFR1
		tst	r10, #0xf << 16		@ hierarchical cache (ARMv7)
		mov	r10, #0
		beq	hierarchical
		mcr	p15, 0, r10, c7, c14, 0	@ clean+invalidate D
		b	iflush
hierarchical:
		mcr	p15, 0, r10, c7, c10, 5	@ DMB
		stmfd	sp!, {r0-r7, r9-r11}
		mrc	p15, 1, r0, c0, c0, 1	@ read clidr
		ands	r3, r0, #0x7000000	@ extract loc from clidr
		mov	r3, r3, lsr #23		@ left align loc bit field
		beq	finished		@ if loc is 0, then no need to clean
		mov	r10, #0			@ start clean at cache level 0
loop1:
		add	r2, r10, r10, lsr #1	@ work out 3x current cache level
		mov	r1, r0, lsr r2		@ extract cache type bits from clidr
		and	r1, r1, #7		@ mask of the bits for current cache only
		cmp	r1, #2			@ see what cache we have at this level
		blt	skip			@ skip if no cache, or just i-cache
		mcr	p15, 2, r10, c0, c0, 0	@ select current cache level in cssr
		mcr	p15, 0, r10, c7, c5, 4	@ isb to sych the new cssr&csidr
		mrc	p15, 1, r1, c0, c0, 0	@ read the new csidr
		and	r2, r1, #7		@ extract the length of the cache lines
		add	r2, r2, #4		@ add 4 (line length offset)
		ldr	r4, =0x3ff
		ands	r4, r4, r1, lsr #3	@ find maximum number on the way size
		clz	r5, r4			@ find bit position of way size increment
		ldr	r7, =0x7fff
		ands	r7, r7, r1, lsr #13	@ extract max number of the index size
loop2:
		mov	r9, r4			@ create working copy of max way size
loop3:
 ARM(		orr	r11, r10, r9, lsl r5	) @ factor way and cache number into r11
 ARM(		orr	r11, r11, r7, lsl r2	) @ factor index number into r11
 THUMB(		lsl	r6, r9, r5		)
 THUMB(		orr	r11, r10, r6		) @ factor way and cache number into r11
 THUMB(		lsl	r6, r7, r2		)
 THUMB(		orr	r11, r11, r6		) @ factor index number into r11
		mcr	p15, 0, r11, c7, c14, 2	@ clean & invalidate by set/way
		subs	r9, r9, #1		@ decrement the way
		bge	loop3
		subs	r7, r7, #1		@ decrement the index
		bge	loop2
skip:
		add	r10, r10, #2		@ increment cache number
		cmp	r3, r10
		bgt	loop1
finished:
		ldmfd	sp!, {r0-r7, r9-r11}
		mov	r10, #0			@ swith back to cache level 0
		mcr	p15, 2, r10, c0, c0, 0	@ select current cache level in cssr
iflush:
		mcr	p15, 0, r10, c7, c10, 4	@ DSB
		mcr	p15, 0, r10, c7, c5, 0	@ invalidate I+BTB
		mcr	p15, 0, r10, c7, c10, 4	@ DSB
		mcr	p15, 0, r10, c7, c5, 4	@ ISB
		mov	pc, lr

__armv5tej_mmu_cache_flush:
1:		mrc	p15, 0, r15, c7, c14, 3	@ test,clean,invalidate D cache
		bne	1b
		mcr	p15, 0, r0, c7, c5, 0	@ flush I cache
		mcr	p15, 0, r0, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv4_mmu_cache_flush:
		mov	r2, #64*1024		@ default: 32K dcache size (*2)
		mov	r11, #32		@ default: 32 byte line size
		mrc	p15, 0, r3, c0, c0, 1	@ read cache type
		teq	r3, r9			@ cache ID register present?
		beq	no_cache_id
		mov	r1, r3, lsr #18
		and	r1, r1, #7
		mov	r2, #1024
		mov	r2, r2, lsl r1		@ base dcache size *2
		tst	r3, #1 << 14		@ test M bit
		addne	r2, r2, r2, lsr #1	@ +1/2 size if M == 1
		mov	r3, r3, lsr #12
		and	r3, r3, #3
		mov	r11, #8
		mov	r11, r11, lsl r3	@ cache line size in bytes
no_cache_id:
		mov	r1, pc
		bic	r1, r1, #63		@ align to longest cache line
		add	r2, r1, r2
1:
 ARM(		ldr	r3, [r1], r11		) @ s/w flush D cache
 THUMB(		ldr     r3, [r1]		) @ s/w flush D cache
 THUMB(		add     r1, r1, r11		)
		teq	r1, r2
		bne	1b

		mcr	p15, 0, r1, c7, c5, 0	@ flush I cache
		mcr	p15, 0, r1, c7, c6, 0	@ flush D cache
		mcr	p15, 0, r1, c7, c10, 4	@ drain WB
		mov	pc, lr

__armv3_mmu_cache_flush:
__armv3_mpu_cache_flush:
		mov	r1, #0
		mcr	p15, 0, r1, c7, c0, 0	@ invalidate whole cache v3
		mov	pc, lr

/*
 * Various debugging routines for printing hex characters and
 * memory, which again must be relocatable.
 */
#ifdef DEBUG
		.align	2
		.type	phexbuf,#object
phexbuf:	.space	12
		.size	phexbuf, . - phexbuf

@ phex corrupts {r0, r1, r2, r3}
phex:		adr	r3, phexbuf
		mov	r2, #0
		strb	r2, [r3, r1]
1:		subs	r1, r1, #1
		movmi	r0, r3
		bmi	puts
		and	r2, r0, #15
		mov	r0, r0, lsr #4
		cmp	r2, #10
		addge	r2, r2, #7
		add	r2, r2, #'0'
		strb	r2, [r3, r1]
		b	1b

@ puts corrupts {r0, r1, r2, r3}
puts:		loadsp	r3, r1
1:		ldrb	r2, [r0], #1
		teq	r2, #0
		moveq	pc, lr
2:		writeb	r2, r3
		mov	r1, #0x00020000
3:		subs	r1, r1, #1
		bne	3b
		teq	r2, #'\n'
		moveq	r2, #'\r'
		beq	2b
		teq	r0, #0
		bne	1b
		mov	pc, lr
@ putc corrupts {r0, r1, r2, r3}
putc:
		mov	r2, r0
		mov	r0, #0
		loadsp	r3, r1
		b	2b

@ memdump corrupts {r0, r1, r2, r3, r10, r11, r12, lr}
memdump:	mov	r12, r0
		mov	r10, lr
		mov	r11, #0
2:		mov	r0, r11, lsl #2
		add	r0, r0, r12
		mov	r1, #8
		bl	phex
		mov	r0, #':'
		bl	putc
1:		mov	r0, #' '
		bl	putc
		ldr	r0, [r12, r11, lsl #2]
		mov	r1, #8
		bl	phex
		and	r0, r11, #7
		teq	r0, #3
		moveq	r0, #' '
		bleq	putc
		and	r0, r11, #7
		add	r11, r11, #1
		teq	r0, #7
		bne	1b
		mov	r0, #'\n'
		bl	putc
		cmp	r11, #64
		blt	2b
		mov	pc, r10
#endif

		.ltorg
reloc_code_end:

		.align
		.section ".stack", "aw", %nobits
.L_user_stack:	.space	4096
.L_user_stack_end:
