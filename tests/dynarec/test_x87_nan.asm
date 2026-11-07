; Test x87 NaN semantics: a NaN produced by the operation is the negative "real indefinite",
; NaN operands propagate quieted with their payload and sign. Run with BOX64_DYNAREC_FASTNAN=0.
; Build: nasm -f elf64 -o test_x87_nan.o test_x87_nan.asm && ld.lld -m elf_x86_64 -o bin/test_x87_nan test_x87_nan.o
%include "test_framework.inc"

section .data
    t1_name:  db "fsubp inf-inf -> indefinite", 0
    t2_name:  db "fmulp 0*inf -> indefinite", 0
    t3_name:  db "fdivp 0/0 -> indefinite", 0
    t4_name:  db "fsqrt(-1) -> indefinite", 0
    t5_name:  db "fadd qword mem -inf+inf -> indefinite", 0
    t6_name:  db "fimul dword 0 with inf -> indefinite", 0
    t7_name:  db "fidiv word 0/0 -> indefinite", 0
    t8_name:  db "faddp SNaN operand -> quieted, payload kept", 0
    t9_name:  db "fmulp -QNaN operand propagates", 0
    t10_name: db "fmulp inf*2 untouched", 0
    t11_name: db "fsub st0,st1 (D8) inf-inf -> indefinite", 0
    t12_name: db "fdivp single 0/0 -> indefinite", 0
    t13_name: db "fsubrp inf-inf -> indefinite", 0
    t14_name: db "fdivr qword mem 0/0 -> indefinite", 0
    align 8
    v_inf:   dq 0x7FF0000000000000
    v_ninf:  dq 0xFFF0000000000000
    v_m1:    dq 0xBFF0000000000000
    v_two:   dq 0x4000000000000000
    v_zero:  dq 0
    v_snan:  dq 0x7FF4000000000001
    v_nqnan: dq 0xFFF8000000000123
    v_zero32: dd 0
    v_zero16: dw 0
    v_zerof:  dd 0

section .bss
    alignb 8
    out: resb 8

section .text
global _start

_start:
    INIT_TESTS
    finit

    TEST_CASE t1_name
    fld qword [rel v_inf]
    fld qword [rel v_inf]
    fsubp st1, st0
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t2_name
    fldz
    fld qword [rel v_inf]
    fmulp st1, st0
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t3_name
    fldz
    fldz
    fdivp st1, st0
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t4_name
    fld qword [rel v_m1]
    fsqrt
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t5_name
    fld qword [rel v_ninf]
    fadd qword [rel v_inf]
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t6_name
    fld qword [rel v_inf]
    fimul dword [rel v_zero32]
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t7_name
    fldz
    fidiv word [rel v_zero16]
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t8_name
    fld qword [rel v_snan]
    fld1
    faddp st1, st0
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0x7FFC000000000001

    TEST_CASE t9_name
    fld qword [rel v_nqnan]
    fld1
    fmulp st1, st0
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000123

    TEST_CASE t10_name
    fld qword [rel v_inf]
    fld qword [rel v_two]
    fmulp st1, st0
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0x7FF0000000000000

    TEST_CASE t11_name
    fld qword [rel v_inf]
    fld qword [rel v_inf]
    fsub st0, st1
    fstp qword [rel out]
    fstp st0
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t12_name
    fld dword [rel v_zerof]
    fld dword [rel v_zerof]
    fdivp st1, st0
    fstp dword [rel out]
    mov eax, [rel out]
    CHECK_EQ_32 eax, 0xFFC00000

    TEST_CASE t13_name
    fld qword [rel v_inf]
    fld qword [rel v_inf]
    fsubrp st1, st0
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    TEST_CASE t14_name
    fldz
    fdivr qword [rel v_zero]
    fstp qword [rel out]
    mov rax, [rel out]
    CHECK_EQ_64 rax, 0xFFF8000000000000

    END_TESTS
