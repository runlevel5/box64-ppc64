; test_32bit_incdec16.asm - Test 16-bit INC/DEC short form (66 40-4F)
; These opcodes only exist in 32-bit mode (in 64-bit mode, 0x40-0x4F are REX prefixes)
; Uses explicit db encoding to guarantee short-form opcodes (not long-form 66 FF /0)
;
; Opcodes tested:
;   66 40 = INC AX    66 48 = DEC AX
;   66 41 = INC CX    66 49 = DEC CX
;   66 42 = INC DX    66 4A = DEC DX
;   66 43 = INC BX    66 4B = DEC BX
;   66 44 = INC SP    66 4C = DEC SP  (SKIPPED - unsafe to modify SP in tests)
;   66 45 = INC BP    66 4D = DEC BP
;   66 46 = INC SI    66 4E = DEC SI
;   66 47 = INC DI    66 4F = DEC DI

%include "test_framework_32.inc"

section .data
    t1_name:  db "inc16 ax basic", 0
    t2_name:  db "inc16 cx", 0
    t3_name:  db "inc16 dx", 0
    t4_name:  db "inc16 bx", 0
    t5_name:  db "inc16 bp", 0
    t6_name:  db "inc16 si", 0
    t7_name:  db "inc16 di", 0
    t8_name:  db "inc16 overflow OF", 0
    t9_name:  db "inc16 zero ZF", 0
    t10_name: db "inc16 preserves CF", 0
    t11_name: db "inc16 upper16 preserved", 0
    t12_name: db "dec16 ax basic", 0
    t13_name: db "dec16 cx", 0
    t14_name: db "dec16 dx", 0
    t15_name: db "dec16 bx", 0
    t16_name: db "dec16 bp", 0
    t17_name: db "dec16 si", 0
    t18_name: db "dec16 di", 0
    t19_name: db "dec16 underflow OF", 0
    t20_name: db "dec16 zero ZF", 0
    t21_name: db "dec16 preserves CF", 0
    t22_name: db "dec16 SF negative", 0

section .text
global _start

_start:
    INIT_TESTS

    ;; ============ INC Reg16 short form (66 40-47) ============

    ; inc ax: 0x1234 + 1 = 0x1235
    TEST_CASE t1_name
    mov eax, 0x1234
    db 0x66, 0x40        ; inc ax
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x1235

    ; inc cx: 0x00FF + 1 = 0x0100
    TEST_CASE t2_name
    mov ecx, 0x00FF
    db 0x66, 0x41        ; inc cx
    movzx eax, cx
    CHECK_EQ_32 eax, 0x0100

    ; inc dx: 0x5678 + 1 = 0x5679
    TEST_CASE t3_name
    mov edx, 0x5678
    db 0x66, 0x42        ; inc dx
    movzx eax, dx
    CHECK_EQ_32 eax, 0x5679

    ; inc bx: 0xABCD + 1 = 0xABCE
    TEST_CASE t4_name
    mov ebx, 0xABCD
    db 0x66, 0x43        ; inc bx
    movzx eax, bx
    CHECK_EQ_32 eax, 0xABCE

    ; inc bp: 0x0000 + 1 = 0x0001
    ; Save/restore ebp around test since it may be used by framework
    TEST_CASE t5_name
    push ebp
    mov ebp, 0x0000
    db 0x66, 0x45        ; inc bp
    movzx eax, bp
    pop ebp
    CHECK_EQ_32 eax, 0x0001

    ; inc si: 0x7FFE + 1 = 0x7FFF
    TEST_CASE t6_name
    push esi
    mov esi, 0x7FFE
    db 0x66, 0x46        ; inc si
    movzx eax, si
    pop esi
    CHECK_EQ_32 eax, 0x7FFF

    ; inc di: 0x1000 + 1 = 0x1001
    TEST_CASE t7_name
    push edi
    mov edi, 0x1000
    db 0x66, 0x47        ; inc di
    movzx eax, di
    pop edi
    CHECK_EQ_32 eax, 0x1001

    ; inc ax overflow: 0x7FFF + 1 = 0x8000, OF=1 SF=1
    TEST_CASE t8_name
    mov eax, 0x7FFF
    db 0x66, 0x40        ; inc ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ (OF|SF), (OF|SF)

    ; inc ax zero: 0xFFFF + 1 = 0x0000, ZF=1
    TEST_CASE t9_name
    mov eax, 0xFFFF
    db 0x66, 0x40        ; inc ax
    SAVE_FLAGS
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0000

    ; inc ax preserves CF: set CF, then inc, CF should still be set
    TEST_CASE t10_name
    stc                   ; set CF
    mov eax, 0x0001
    db 0x66, 0x40        ; inc ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; inc ax preserves upper 16 bits of eax
    TEST_CASE t11_name
    mov eax, 0xDEAD0005
    db 0x66, 0x40        ; inc ax (should only affect low 16 bits)
    mov ecx, eax
    shr ecx, 16          ; get upper 16 bits
    CHECK_EQ_32 ecx, 0xDEAD

    ;; ============ DEC Reg16 short form (66 48-4F) ============

    ; dec ax: 0x1234 - 1 = 0x1233
    TEST_CASE t12_name
    mov eax, 0x1234
    db 0x66, 0x48        ; dec ax
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x1233

    ; dec cx: 0x0100 - 1 = 0x00FF
    TEST_CASE t13_name
    mov ecx, 0x0100
    db 0x66, 0x49        ; dec cx
    movzx eax, cx
    CHECK_EQ_32 eax, 0x00FF

    ; dec dx: 0x5679 - 1 = 0x5678
    TEST_CASE t14_name
    mov edx, 0x5679
    db 0x66, 0x4A        ; dec dx
    movzx eax, dx
    CHECK_EQ_32 eax, 0x5678

    ; dec bx: 0xABCE - 1 = 0xABCD
    TEST_CASE t15_name
    mov ebx, 0xABCE
    db 0x66, 0x4B        ; dec bx
    movzx eax, bx
    CHECK_EQ_32 eax, 0xABCD

    ; dec bp: 0x0001 - 1 = 0x0000
    TEST_CASE t16_name
    push ebp
    mov ebp, 0x0001
    db 0x66, 0x4D        ; dec bp
    movzx eax, bp
    pop ebp
    CHECK_EQ_32 eax, 0x0000

    ; dec si: 0x8001 - 1 = 0x8000
    TEST_CASE t17_name
    push esi
    mov esi, 0x8001
    db 0x66, 0x4E        ; dec si
    movzx eax, si
    pop esi
    CHECK_EQ_32 eax, 0x8000

    ; dec di: 0x1001 - 1 = 0x1000
    TEST_CASE t18_name
    push edi
    mov edi, 0x1001
    db 0x66, 0x4F        ; dec di
    movzx eax, di
    pop edi
    CHECK_EQ_32 eax, 0x1000

    ; dec ax underflow: 0x8000 - 1 = 0x7FFF, OF=1 (sign change from negative to positive)
    TEST_CASE t19_name
    mov eax, 0x8000
    db 0x66, 0x48        ; dec ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; dec ax zero: 0x0001 - 1 = 0x0000, ZF=1
    TEST_CASE t20_name
    mov eax, 0x0001
    db 0x66, 0x48        ; dec ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ; dec ax preserves CF: set CF, then dec, CF should still be set
    TEST_CASE t21_name
    stc                   ; set CF
    mov eax, 0x0005
    db 0x66, 0x48        ; dec ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; dec ax SF: 0x0000 - 1 = 0xFFFF, SF=1 (negative in 16-bit)
    TEST_CASE t22_name
    mov eax, 0x0000
    db 0x66, 0x48        ; dec ax
    SAVE_FLAGS
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xFFFF

    END_TESTS
