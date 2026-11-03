; Test the D8 opcode map: FADD/FMUL/FSUB/FSUBR/FDIV/FDIVR ST0,ST(i) and ST0,float[mem], FCOM/FCOMP.
; Build: nasm -f elf64 -o test_x87_d8.o test_x87_d8.asm && ld.lld -m elf_x86_64 -o bin/test_x87_d8 test_x87_d8.o
%include "test_framework.inc"

section .data
    t1_name: db "fadd st0,st1", 0
    t2_name: db "fmul st0,st1", 0
    t3_name: db "fsub st0,st1", 0
    t4_name: db "fsubr st0,st1", 0
    t5_name: db "fdiv st0,st1", 0
    t6_name: db "fdivr st0,st1", 0
    t7_name: db "fadd dword", 0
    t8_name: db "fmul dword", 0
    t9_name: db "fsub dword", 0
    t10_name: db "fsubr dword", 0
    t11_name: db "fdiv dword", 0
    t12_name: db "fdivr dword", 0
    t13_name: db "fcom st0,st1 greater", 0
    t14_name: db "fcom st0,st1 less", 0
    t15_name: db "fcomp st0,st1 equal", 0
    t16_name: db "fcom st0,st1 unordered", 0
    t17_name: db "fcom dword greater", 0
    t18_name: db "fcomp dword less", 0
    align 8
    v_a:    dq 0x4008000000000000   ; 3.0
    v_b:    dq 0x3FF8000000000000   ; 1.5
    v_f:    dd 0x3E800000           ; 0.25f
    v_nan:  dq 0x7FF8000000000000

section .bss
    alignb 8
    out: resb 8

section .text
global _start

%macro ST_OP 2            ; %1 = instruction, %2 = expected bits ; st1=1.5, st0=3.0
    fld qword [rel v_b]
    fld qword [rel v_a]
    %1
    fstp qword [rel out]
    fstp st0
    mov rax, [rel out]
    CHECK_EQ_64 rax, %2
%endmacro
%macro MEM_OP 2           ; st0=3.0 op 0.25f
    fld qword [rel v_a]
    %1
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, %2
%endmacro

_start:
    INIT_TESTS
    finit

    TEST_CASE t1_name
    ST_OP {fadd st0, st1}, 0x4012000000000000
    TEST_CASE t2_name
    ST_OP {fmul st0, st1}, 0x4012000000000000
    TEST_CASE t3_name
    ST_OP {fsub st0, st1}, 0x3FF8000000000000
    TEST_CASE t4_name
    ST_OP {fsubr st0, st1}, 0xBFF8000000000000
    TEST_CASE t5_name
    ST_OP {fdiv st0, st1}, 0x4000000000000000
    TEST_CASE t6_name
    ST_OP {fdivr st0, st1}, 0x3FE0000000000000
    TEST_CASE t7_name
    MEM_OP {fadd dword [rel v_f]}, 0x400A000000000000
    TEST_CASE t8_name
    MEM_OP {fmul dword [rel v_f]}, 0x3FE8000000000000
    TEST_CASE t9_name
    MEM_OP {fsub dword [rel v_f]}, 0x4006000000000000
    TEST_CASE t10_name
    MEM_OP {fsubr dword [rel v_f]}, 0xC006000000000000
    TEST_CASE t11_name
    MEM_OP {fdiv dword [rel v_f]}, 0x4028000000000000
    TEST_CASE t12_name
    MEM_OP {fdivr dword [rel v_f]}, 0x3FB5555555555555

    ; FCOM status: C3 (0x4000) = equal, C2 (0x0400) + C0 (0x0100) + C3 = unordered, C0 = less
    TEST_CASE t13_name
    fld qword [rel v_b]
    fld qword [rel v_a]
    fcom st1                      ; 3.0 > 1.5 -> all clear
    fnstsw ax
    and eax, 0x4500
    fstp st0
    fstp st0
    CHECK_EQ_32 eax, 0x0000
    TEST_CASE t14_name
    fld qword [rel v_a]
    fld qword [rel v_b]
    fcom st1                      ; 1.5 < 3.0 -> C0
    fnstsw ax
    and eax, 0x4500
    fstp st0
    fstp st0
    CHECK_EQ_32 eax, 0x0100
    TEST_CASE t15_name
    fld qword [rel v_a]
    fld qword [rel v_a]
    fcomp st1                     ; equal -> C3, pops one
    fnstsw ax
    and eax, 0x4500
    fstp st0
    CHECK_EQ_32 eax, 0x4000
    TEST_CASE t16_name
    fld qword [rel v_nan]
    fld qword [rel v_a]
    fcom st1                      ; unordered -> C0 C2 C3
    fnstsw ax
    and eax, 0x4500
    fstp st0
    fstp st0
    CHECK_EQ_32 eax, 0x4500
    TEST_CASE t17_name
    fld qword [rel v_a]
    fcom dword [rel v_f]          ; 3.0 > 0.25
    fnstsw ax
    and eax, 0x4500
    fstp st0
    CHECK_EQ_32 eax, 0x0000
    TEST_CASE t18_name
    fldz
    fcomp dword [rel v_f]         ; 0 < 0.25 -> C0, pops
    fnstsw ax
    and eax, 0x4500
    CHECK_EQ_32 eax, 0x0100

    END_TESTS
