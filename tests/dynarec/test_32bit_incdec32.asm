; test_32bit_incdec32.asm - Test 32-bit INC/DEC short form (0x40-0x4F)
; These opcodes only exist in 32-bit mode (in 64-bit mode, 0x40-0x4F are REX prefixes)
; Already implemented in PPC64LE dynarec - this is a regression test.
;
; Opcodes tested:
;   40 = INC EAX    48 = DEC EAX
;   41 = INC ECX    49 = DEC ECX
;   42 = INC EDX    4A = DEC EDX
;   43 = INC EBX    4B = DEC EBX
;   44 = INC ESP    4C = DEC ESP  (SKIPPED - unsafe to modify ESP in tests)
;   45 = INC EBP    4D = DEC EBP
;   46 = INC ESI    4E = DEC ESI
;   47 = INC EDI    4F = DEC EDI

%include "test_framework_32.inc"

section .data
    t1_name:  db "inc32 eax basic", 0
    t2_name:  db "inc32 ecx", 0
    t3_name:  db "inc32 edx", 0
    t4_name:  db "inc32 ebx", 0
    t5_name:  db "inc32 ebp", 0
    t6_name:  db "inc32 esi", 0
    t7_name:  db "inc32 edi", 0
    t8_name:  db "inc32 overflow OF", 0
    t9_name:  db "inc32 zero ZF", 0
    t10_name: db "inc32 preserves CF", 0
    t11_name: db "dec32 eax basic", 0
    t12_name: db "dec32 ecx", 0
    t13_name: db "dec32 edx", 0
    t14_name: db "dec32 ebx", 0
    t15_name: db "dec32 ebp", 0
    t16_name: db "dec32 esi", 0
    t17_name: db "dec32 edi", 0
    t18_name: db "dec32 underflow OF", 0
    t19_name: db "dec32 zero ZF", 0
    t20_name: db "dec32 preserves CF", 0

section .text
global _start

_start:
    INIT_TESTS

    ;; ============ INC Reg32 short form (0x40-0x47) ============

    ; inc eax: 0x12345678 + 1 = 0x12345679
    TEST_CASE t1_name
    mov eax, 0x12345678
    db 0x40               ; inc eax
    CHECK_EQ_32 eax, 0x12345679

    ; inc ecx: 0x000000FF + 1 = 0x00000100
    TEST_CASE t2_name
    mov ecx, 0x000000FF
    db 0x41               ; inc ecx
    CHECK_EQ_32 ecx, 0x00000100

    ; inc edx: 0xDEADBEEF + 1 = 0xDEADBEF0
    TEST_CASE t3_name
    mov edx, 0xDEADBEEF
    db 0x42               ; inc edx
    CHECK_EQ_32 edx, 0xDEADBEF0

    ; inc ebx: 0x00000000 + 1 = 0x00000001
    TEST_CASE t4_name
    mov ebx, 0x00000000
    db 0x43               ; inc ebx
    CHECK_EQ_32 ebx, 0x00000001

    ; inc ebp
    TEST_CASE t5_name
    push ebp
    mov ebp, 0x10000000
    db 0x45               ; inc ebp
    mov eax, ebp
    pop ebp
    CHECK_EQ_32 eax, 0x10000001

    ; inc esi
    TEST_CASE t6_name
    push esi
    mov esi, 0xFFFFFFFE
    db 0x46               ; inc esi
    mov eax, esi
    pop esi
    CHECK_EQ_32 eax, 0xFFFFFFFF

    ; inc edi
    TEST_CASE t7_name
    push edi
    mov edi, 0x80000000
    db 0x47               ; inc edi
    mov eax, edi
    pop edi
    CHECK_EQ_32 eax, 0x80000001

    ; inc eax overflow: 0x7FFFFFFF + 1 = 0x80000000, OF=1 SF=1
    TEST_CASE t8_name
    mov eax, 0x7FFFFFFF
    db 0x40               ; inc eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ (OF|SF), (OF|SF)

    ; inc eax zero: 0xFFFFFFFF + 1 = 0x00000000, ZF=1
    TEST_CASE t9_name
    mov eax, 0xFFFFFFFF
    db 0x40               ; inc eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ; inc preserves CF
    TEST_CASE t10_name
    stc
    mov eax, 0x00000001
    db 0x40               ; inc eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ;; ============ DEC Reg32 short form (0x48-0x4F) ============

    ; dec eax: 0x12345679 - 1 = 0x12345678
    TEST_CASE t11_name
    mov eax, 0x12345679
    db 0x48               ; dec eax
    CHECK_EQ_32 eax, 0x12345678

    ; dec ecx: 0x00000100 - 1 = 0x000000FF
    TEST_CASE t12_name
    mov ecx, 0x00000100
    db 0x49               ; dec ecx
    CHECK_EQ_32 ecx, 0x000000FF

    ; dec edx: 0xDEADBEF0 - 1 = 0xDEADBEEF
    TEST_CASE t13_name
    mov edx, 0xDEADBEF0
    db 0x4A               ; dec edx
    CHECK_EQ_32 edx, 0xDEADBEEF

    ; dec ebx: 0x00000001 - 1 = 0x00000000
    TEST_CASE t14_name
    mov ebx, 0x00000001
    db 0x4B               ; dec ebx
    CHECK_EQ_32 ebx, 0x00000000

    ; dec ebp
    TEST_CASE t15_name
    push ebp
    mov ebp, 0x10000001
    db 0x4D               ; dec ebp
    mov eax, ebp
    pop ebp
    CHECK_EQ_32 eax, 0x10000000

    ; dec esi
    TEST_CASE t16_name
    push esi
    mov esi, 0x00000001
    db 0x4E               ; dec esi
    mov eax, esi
    pop esi
    CHECK_EQ_32 eax, 0x00000000

    ; dec edi
    TEST_CASE t17_name
    push edi
    mov edi, 0x80000001
    db 0x4F               ; dec edi
    mov eax, edi
    pop edi
    CHECK_EQ_32 eax, 0x80000000

    ; dec eax underflow: 0x80000000 - 1 = 0x7FFFFFFF, OF=1
    TEST_CASE t18_name
    mov eax, 0x80000000
    db 0x48               ; dec eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; dec eax zero: 0x00000001 - 1 = 0x00000000, ZF=1
    TEST_CASE t19_name
    mov eax, 0x00000001
    db 0x48               ; dec eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ; dec preserves CF
    TEST_CASE t20_name
    stc
    mov eax, 0x00000005
    db 0x48               ; dec eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    END_TESTS
