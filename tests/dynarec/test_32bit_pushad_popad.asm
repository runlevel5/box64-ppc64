; test_32bit_pushad_popad.asm - Test PUSHAD/POPAD (0x60/0x61) and PUSHA/POPA 16-bit (66 60/66 61)
; These opcodes only exist in 32-bit mode (invalid in 64-bit mode)
;
; Opcodes tested:
;   60 = PUSHAD (push all 32-bit registers)
;   61 = POPAD  (pop all 32-bit registers)
;   66 60 = PUSHA (push all 16-bit registers)
;   66 61 = POPA  (pop all 16-bit registers)

%include "test_framework_32.inc"

section .data
    t1_name:  db "pushad/popad roundtrip eax", 0
    t2_name:  db "pushad/popad roundtrip ecx", 0
    t3_name:  db "pushad/popad roundtrip edx", 0
    t4_name:  db "pushad/popad roundtrip ebx", 0
    t5_name:  db "pushad/popad roundtrip ebp", 0
    t6_name:  db "pushad/popad roundtrip esi", 0
    t7_name:  db "pushad/popad roundtrip edi", 0
    t8_name:  db "pushad/popad esp restored", 0
    t9_name:  db "pusha16/popa16 roundtrip ax", 0
    t10_name: db "pusha16/popa16 roundtrip cx", 0
    t11_name: db "pusha16/popa16 roundtrip bx", 0
    t12_name: db "pusha16/popa16 upper16 preserved", 0

section .bss
    saved_esp: resd 1
    saved_eax: resd 1
    saved_ecx: resd 1
    saved_edx: resd 1
    saved_ebx: resd 1
    saved_ebp: resd 1
    saved_esi: resd 1
    saved_edi: resd 1

section .text
global _start

_start:
    INIT_TESTS

    ;; ============ PUSHAD/POPAD (0x60/0x61) ============
    ;; PUSHAD pushes: EAX, ECX, EDX, EBX, original-ESP, EBP, ESI, EDI
    ;; POPAD pops:    EDI, ESI, EBP, (skip ESP), EBX, EDX, ECX, EAX

    ; Load known values, pushad, clobber, popad, verify all restored
    ; Save framework state first
    mov [saved_esp], esp

    mov eax, 0x11111111
    mov ecx, 0x22222222
    mov edx, 0x33333333
    mov ebx, 0x44444444
    mov ebp, 0x55555555
    mov esi, 0x66666666
    mov edi, 0x77777777

    pushad                ; push all 8 registers (32 bytes)

    ; Clobber all registers
    xor eax, eax
    xor ecx, ecx
    xor edx, edx
    xor ebx, ebx
    xor ebp, ebp
    xor esi, esi
    xor edi, edi

    popad                 ; restore all registers

    ; Save results to memory (can't use CHECK_EQ_32 yet - it clobbers regs)
    mov [saved_eax], eax
    mov [saved_ecx], ecx
    mov [saved_edx], edx
    mov [saved_ebx], ebx
    mov [saved_ebp], ebp
    mov [saved_esi], esi
    mov [saved_edi], edi

    ; Restore framework-safe state
    mov esp, [saved_esp]

    ; Now check each register value
    TEST_CASE t1_name
    mov eax, [saved_eax]
    CHECK_EQ_32 eax, 0x11111111

    TEST_CASE t2_name
    mov eax, [saved_ecx]
    CHECK_EQ_32 eax, 0x22222222

    TEST_CASE t3_name
    mov eax, [saved_edx]
    CHECK_EQ_32 eax, 0x33333333

    TEST_CASE t4_name
    mov eax, [saved_ebx]
    CHECK_EQ_32 eax, 0x44444444

    TEST_CASE t5_name
    mov eax, [saved_ebp]
    CHECK_EQ_32 eax, 0x55555555

    TEST_CASE t6_name
    mov eax, [saved_esi]
    CHECK_EQ_32 eax, 0x66666666

    TEST_CASE t7_name
    mov eax, [saved_edi]
    CHECK_EQ_32 eax, 0x77777777

    ; Verify ESP is restored after pushad/popad
    ; (Can't compare esp directly inside CHECK_EQ_32 because the macro
    ;  pushes registers, altering esp before the cmp. Save esp first.)
    TEST_CASE t8_name
    mov [saved_edi], esp    ; reuse saved_edi as temp storage
    mov eax, [saved_edi]
    CHECK_EQ_32 eax, [saved_esp]

    ;; ============ PUSHA/POPA 16-bit (66 60 / 66 61) ============
    ;; PUSHA pushes 16-bit: AX, CX, DX, BX, original-SP, BP, SI, DI (16 bytes total)
    ;; POPA pops 16-bit:    DI, SI, BP, (skip SP), BX, DX, CX, AX

    ; Set known 32-bit values with distinct upper and lower halves
    TEST_CASE t9_name
    mov [saved_esp], esp

    mov eax, 0xAAAA1111
    mov ecx, 0xBBBB2222
    mov edx, 0xCCCC3333
    mov ebx, 0xDDDD4444
    mov ebp, 0xEEEE5555
    mov esi, 0xFFFF6666
    mov edi, 0x99997777

    db 0x66, 0x60         ; pusha (16-bit)

    ; Clobber low 16 bits of all registers
    and eax, 0xFFFF0000
    and ecx, 0xFFFF0000
    and edx, 0xFFFF0000
    and ebx, 0xFFFF0000
    and ebp, 0xFFFF0000
    and esi, 0xFFFF0000
    and edi, 0xFFFF0000

    db 0x66, 0x61         ; popa (16-bit)

    ; Save results
    mov [saved_eax], eax
    mov [saved_ecx], ecx
    mov [saved_ebx], ebx
    mov [saved_ebp], ebp

    ; Restore ESP
    mov esp, [saved_esp]

    ; Check AX was restored
    mov eax, [saved_eax]
    movzx eax, ax
    CHECK_EQ_32 eax, 0x1111

    ; Check CX was restored
    TEST_CASE t10_name
    mov eax, [saved_ecx]
    movzx eax, ax
    CHECK_EQ_32 eax, 0x2222

    ; Check BX was restored
    TEST_CASE t11_name
    mov eax, [saved_ebx]
    movzx eax, ax
    CHECK_EQ_32 eax, 0x4444

    ; Check upper 16 bits of eax preserved by POPA (only low 16 bits should change)
    TEST_CASE t12_name
    mov eax, [saved_eax]
    shr eax, 16
    CHECK_EQ_32 eax, 0xAAAA

    END_TESTS
