; Functional test for COMISS/UCOMISS (and COMISD/UCOMISD): flag results for every
; ordering, register and memory forms, signed zero, SNaN/QNaN, clearing of
; OF/SF/AF, high-lane independence, and flag consumers (setcc, cmovcc, jcc)
; in the same block and across a block exit.
; Build: nasm -f elf64 -o test_comiss.o test_comiss.asm && ld.lld -m elf_x86_64 -o bin/test_comiss test_comiss.o
%include "test_framework.inc"

%define FMASK 0x8D5            ; CF|PF|AF|ZF|SF|OF
%define F_EQ  0x40             ; ZF
%define F_LT  0x01             ; CF
%define F_GT  0x00
%define F_UN  0x45             ; ZF|PF|CF

section .data
    t1_name:  db "ucomiss xmm,xmm equal -> ZF", 0
    t2_name:  db "ucomiss xmm,xmm less -> CF", 0
    t3_name:  db "ucomiss xmm,xmm greater -> none", 0
    t4_name:  db "ucomiss xmm,mem QNaN -> ZF|PF|CF", 0
    t5_name:  db "comiss xmm,mem QNaN -> ZF|PF|CF", 0
    t6_name:  db "comiss xmm,xmm SNaN operand -> ZF|PF|CF", 0
    t7_name:  db "ucomiss +0 vs -0 -> equal", 0
    t8_name:  db "comiss clears OF/SF/AF left by add", 0
    t9_name:  db "ucomiss ignores the upper lanes", 0
    t10_name: db "ucomiss xmm,[base+index*4+disp] less", 0
    t11_name: db "setcc after comiss greater", 0
    t12_name: db "setcc after ucomiss unordered", 0
    t13_name: db "setcc after ucomiss equal", 0
    t14_name: db "jbe after comiss with movzx/movss in between (greater)", 0
    t15_name: db "jbe after comiss with movzx/movss in between (equal)", 0
    t16_name: db "cmovb after ucomiss less", 0
    t17_name: db "jp out of the block after ucomiss unordered, landing reads ZF/CF/PF", 0
    t18_name: db "jnp out of the block after comiss less, landing reads ZF/CF/PF", 0
    t19_name: db "ucomiss xmm,xmm same register non-NaN -> equal", 0
    t20_name: db "ucomiss xmm,xmm same register NaN -> unordered", 0
    t21_name: db "ucomisd xmm,xmm equal -> ZF", 0
    t22_name: db "comisd xmm,mem less -> CF", 0
    t23_name: db "ucomisd xmm,mem QNaN -> ZF|PF|CF", 0
    t24_name: db "comisd xmm,xmm greater -> none", 0
    align 16
    f_one:   dd 0x3f800000
    f_two:   dd 0x40000000
    f_qnan:  dd 0x7fc00000
    f_snan:  dd 0x7f800001
    f_pzero: dd 0x00000000
    f_nzero: dd 0x80000000
    f_three: dd 0x40400000
    v_one_hi9:  dd 0x3f800000, 0x41100000, 0x41100000, 0x41100000
    v_one_hi3:  dd 0x3f800000, 0x40400000, 0x40400000, 0x40400000
    f_table: dd 0x00000000, 0x3f800000, 0x40000000, 0x40400000, 0x40800000
    align 8
    d_one:   dq 0x3ff0000000000000
    d_two:   dq 0x4000000000000000
    d_qnan:  dq 0x7ff8000000000000
section .bss
    alignb 4
    scratch32: resd 1
    scratch16: resw 1

section .text
global _start

; out-of-block landing pads (backward targets); rdx holds the continuation address
land_jp:
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
    jmp rdx
land_jnp:
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
    jmp rdx

; eax = a | ae<<1 | b<<2 | be<<3 | e<<4 | ne<<5 | p<<6 | np<<7 from the current flags
%macro SETCC_MASK 0
    seta al
    setae bl
    setb cl
    setbe dl
    sete sil
    setne dil
    setp r8b
    setnp r9b
    movzx eax, al
    movzx ebx, bl
    movzx ecx, cl
    movzx edx, dl
    movzx esi, sil
    movzx edi, dil
    movzx r8d, r8b
    movzx r9d, r9b
    shl ebx, 1
    shl ecx, 2
    shl edx, 3
    shl esi, 4
    shl edi, 5
    shl r8d, 6
    shl r9d, 7
    or eax, ebx
    or eax, ecx
    or eax, edx
    or eax, esi
    or eax, edi
    or eax, r8d
    or eax, r9d
%endmacro

_start:
    INIT_TESTS

    TEST_CASE t1_name
    movss xmm0, [rel f_one]
    movss xmm1, [rel f_one]
    ucomiss xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_EQ

    TEST_CASE t2_name
    movss xmm0, [rel f_one]
    movss xmm1, [rel f_two]
    ucomiss xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_LT

    TEST_CASE t3_name
    movss xmm0, [rel f_two]
    movss xmm1, [rel f_one]
    ucomiss xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_GT

    TEST_CASE t4_name
    movss xmm0, [rel f_one]
    ucomiss xmm0, [rel f_qnan]
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_UN

    TEST_CASE t5_name
    movss xmm0, [rel f_one]
    comiss xmm0, [rel f_qnan]
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_UN

    TEST_CASE t6_name
    movss xmm0, [rel f_snan]
    movss xmm1, [rel f_one]
    comiss xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_UN

    TEST_CASE t7_name
    movss xmm0, [rel f_pzero]
    movss xmm1, [rel f_nzero]
    ucomiss xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_EQ

    TEST_CASE t8_name
    movss xmm0, [rel f_two]
    movss xmm1, [rel f_one]
    mov eax, 0x7fffffff
    add eax, 1               ; OF=1 SF=1 AF=1 PF=0 CF=0 ZF=0
    comiss xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_GT

    TEST_CASE t9_name
    movups xmm0, [rel v_one_hi9]
    movups xmm1, [rel v_one_hi3]
    ucomiss xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_EQ

    TEST_CASE t10_name
    movss xmm0, [rel f_one]
    lea rdi, [rel f_table]
    mov eax, 1
    ucomiss xmm0, [rdi + rax*4 + 4]   ; f_table[2] = 2.0
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_LT

    TEST_CASE t11_name
    movss xmm0, [rel f_two]
    movss xmm1, [rel f_one]
    comiss xmm0, xmm1
    SETCC_MASK
    CHECK_EQ_32 eax, 0xA3

    TEST_CASE t12_name
    movss xmm0, [rel f_two]
    ucomiss xmm0, [rel f_qnan]
    SETCC_MASK
    CHECK_EQ_32 eax, 0x5C

    TEST_CASE t13_name
    movss xmm0, [rel f_two]
    movss xmm1, [rel f_two]
    ucomiss xmm0, xmm1
    SETCC_MASK
    CHECK_EQ_32 eax, 0x9A

    TEST_CASE t14_name
    movss xmm0, [rel f_two]
    mov word [rel scratch16], 5
    comiss xmm0, [rel f_one]
    movzx r15d, word [rel scratch16]
    movss [rel scratch32], xmm0
    mov eax, 1
    jbe .t14_skip
    mov eax, 2
.t14_skip:
    CHECK_EQ_32 eax, 2

    TEST_CASE t15_name
    movss xmm0, [rel f_one]
    comiss xmm0, [rel f_one]
    movzx r15d, word [rel scratch16]
    movss [rel scratch32], xmm0
    mov eax, 1
    jbe .t15_skip
    mov eax, 2
.t15_skip:
    CHECK_EQ_32 eax, 1

    TEST_CASE t16_name
    movss xmm0, [rel f_one]
    ucomiss xmm0, [rel f_two]
    mov eax, 0
    mov ecx, 1
    cmovb eax, ecx
    CHECK_EQ_32 eax, 1

    TEST_CASE t17_name
    movss xmm0, [rel f_one]
    lea rdx, [rel .t17_cont]
    ucomiss xmm0, [rel f_qnan]
    jp land_jp               ; backward target: leaves the block with the flags live
    mov eax, 0xdead
.t17_cont:
    CHECK_EQ_32 eax, 7

    TEST_CASE t18_name
    movss xmm0, [rel f_one]
    lea rdx, [rel .t18_cont]
    comiss xmm0, [rel f_two]
    jnp land_jnp
    mov eax, 0xdead
.t18_cont:
    CHECK_EQ_32 eax, 2

    TEST_CASE t19_name
    movss xmm3, [rel f_three]
    ucomiss xmm3, xmm3
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_EQ

    TEST_CASE t20_name
    movss xmm3, [rel f_qnan]
    ucomiss xmm3, xmm3
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_UN

    TEST_CASE t21_name
    movsd xmm0, [rel d_one]
    movsd xmm1, [rel d_one]
    ucomisd xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_EQ

    TEST_CASE t22_name
    movsd xmm0, [rel d_one]
    comisd xmm0, [rel d_two]
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_LT

    TEST_CASE t23_name
    movsd xmm0, [rel d_one]
    ucomisd xmm0, [rel d_qnan]
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_UN

    TEST_CASE t24_name
    movsd xmm0, [rel d_two]
    movsd xmm1, [rel d_one]
    comisd xmm0, xmm1
    SAVE_FLAGS
    CHECK_FLAGS_EQ FMASK, F_GT

    END_TESTS
