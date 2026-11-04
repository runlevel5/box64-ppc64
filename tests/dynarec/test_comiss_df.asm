; Regression test: the flags of a scalar single compare must survive a block
; exit when an earlier instruction left a deferred-flags record in emu->df.
; Sequence mirrors Broken Sword Reforged's credits layout loop: a 16-bit TEST
; whose jump leaves the block (deferred record written to emu->df), a fused
; TEST with an in-block jump (no record written), PXOR+UCOMISS (flags written
; directly) and an indirect jump out of the block. The landing block reads
; ZF/CF/PF with setcc and must see the compare, not the stale 16-bit TEST.
; Build: nasm -f elf64 -o test_comiss_df.o test_comiss_df.asm && ld.lld -m elf_x86_64 -o bin/test_comiss_df test_comiss_df.o
%include "test_framework.inc"

section .data
    t1_name: db "ucomiss equal after deferred 16-bit test, flags cross an indirect jump", 0
    t2_name: db "ucomiss below after deferred 16-bit test", 0
    t3_name: db "ucomiss unordered after deferred 16-bit test", 0
    t4_name: db "comiss above after deferred 16-bit test", 0
    align 4
    f_zero: dd 0
    f_one:  dd 0x3f800000
    f_nan:  dd 0x7fc00000
    f_neg:  dd 0xbf800000

section .text
global _start

; never reached: a backward, out-of-block target for the first jz
bad_exit:
    mov eax, 60
    mov edi, 99
    syscall

; rdi -> float compared against xmm3 (= 0.0)
; leaves eax = ZF | CF<<1 | PF<<2 as observed in the block entered by the indirect jump
%macro CMP_SEQ 1
    mov r15d, 5             ; nonzero "line type"
    mov rsi, 1
    test r15w, r15w
    jz bad_exit             ; leaves the block: the 16-bit record is written to emu->df
    test rsi, rsi
    jz %%bad                ; stays in the block: fused, no record written
    pxor xmm3, xmm3
    %1 xmm3, [rdi]          ; flags written directly to the flags register
    lea rax, [rel %%land]
    jmp rax                 ; indirect jump: block boundary
%%bad:
    mov eax, 0xdead
    jmp %%done
%%land:
    setz al
    setc bl
    setp cl
    movzx eax, al
    movzx ebx, bl
    movzx ecx, cl
    add ebx, ebx
    shl ecx, 2
    or eax, ebx
    or eax, ecx
%%done:
%endmacro

_start:
    INIT_TESTS

    TEST_CASE t1_name
    lea rdi, [rel f_zero]
    CMP_SEQ ucomiss
    CHECK_EQ_32 eax, 1

    TEST_CASE t2_name
    lea rdi, [rel f_one]
    CMP_SEQ ucomiss
    CHECK_EQ_32 eax, 2

    TEST_CASE t3_name
    lea rdi, [rel f_nan]
    CMP_SEQ ucomiss
    CHECK_EQ_32 eax, 7

    TEST_CASE t4_name
    lea rdi, [rel f_neg]
    CMP_SEQ comiss
    CHECK_EQ_32 eax, 0

    END_TESTS
