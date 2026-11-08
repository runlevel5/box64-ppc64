; test_32bit_segment_push.asm - Test PUSH/POP segment registers (32-bit only)
; These opcodes are invalid in 64-bit mode.
;
; Opcodes tested:
;   06 = PUSH ES       07 = POP ES
;   0E = PUSH CS       (no POP CS exists)
;   16 = PUSH SS       17 = POP SS
;   1E = PUSH DS       1F = POP DS
;   66 06 = PUSH ES (16-bit)    66 07 = POP ES (16-bit)
;   66 1E = PUSH DS (16-bit)    66 1F = POP DS (16-bit)
;
; Note: Under box64 flat memory model, segment registers have fixed values.
; We test round-trip preservation (push then pop back), not segment semantics.

%include "test_framework_32.inc"

section .data
    t1_name:  db "push/pop ES roundtrip", 0
    t2_name:  db "push CS value", 0
    t3_name:  db "push/pop SS roundtrip", 0
    t4_name:  db "push/pop DS roundtrip", 0
    t5_name:  db "push/pop ES 16bit roundtrip", 0
    t6_name:  db "push/pop DS 16bit roundtrip", 0
    t7_name:  db "push ES then pop via register", 0
    t8_name:  db "push DS then pop via register", 0

section .bss
    saved_seg: resd 1

section .text
global _start

_start:
    INIT_TESTS

    ;; ============ PUSH/POP ES (0x06/0x07) ============

    ; Push ES, pop ES - round trip should preserve value
    TEST_CASE t1_name
    mov eax, es           ; save original ES
    db 0x06               ; push es
    ; Modify ES to something else (if possible, but pop should restore)
    db 0x07               ; pop es
    mov ecx, es           ; read ES after pop
    cmp eax, ecx          ; should be same as original
    je .t1_eq
    mov ecx, 0
    jmp .t1_check
.t1_eq:
    mov ecx, 1
.t1_check:
    CHECK_EQ_32 ecx, 1

    ;; ============ PUSH CS (0x0E) ============
    ;; There is no POP CS instruction. Just verify push doesn't crash
    ;; and pushes a reasonable value.

    TEST_CASE t2_name
    mov eax, cs           ; read CS into eax
    db 0x0E               ; push cs
    pop ecx               ; pop into ecx (generic pop)
    ; CS value from push should match CS value from mov
    cmp eax, ecx
    je .t2_eq
    mov ecx, 0
    jmp .t2_check
.t2_eq:
    mov ecx, 1
.t2_check:
    CHECK_EQ_32 ecx, 1

    ;; ============ PUSH/POP SS (0x16/0x17) ============

    TEST_CASE t3_name
    mov eax, ss
    db 0x16               ; push ss
    db 0x17               ; pop ss
    mov ecx, ss
    cmp eax, ecx
    je .t3_eq
    mov ecx, 0
    jmp .t3_check
.t3_eq:
    mov ecx, 1
.t3_check:
    CHECK_EQ_32 ecx, 1

    ;; ============ PUSH/POP DS (0x1E/0x1F) ============

    TEST_CASE t4_name
    mov eax, ds
    db 0x1E               ; push ds
    db 0x1F               ; pop ds
    mov ecx, ds
    cmp eax, ecx
    je .t4_eq
    mov ecx, 0
    jmp .t4_check
.t4_eq:
    mov ecx, 1
.t4_check:
    CHECK_EQ_32 ecx, 1

    ;; ============ PUSH/POP ES 16-bit (66 06 / 66 07) ============

    TEST_CASE t5_name
    mov eax, es
    db 0x66, 0x06         ; push es (16-bit push)
    db 0x66, 0x07         ; pop es (16-bit pop)
    mov ecx, es
    cmp eax, ecx
    je .t5_eq
    mov ecx, 0
    jmp .t5_check
.t5_eq:
    mov ecx, 1
.t5_check:
    CHECK_EQ_32 ecx, 1

    ;; ============ PUSH/POP DS 16-bit (66 1E / 66 1F) ============

    TEST_CASE t6_name
    mov eax, ds
    db 0x66, 0x1E         ; push ds (16-bit push)
    db 0x66, 0x1F         ; pop ds (16-bit pop)
    mov ecx, ds
    cmp eax, ecx
    je .t6_eq
    mov ecx, 0
    jmp .t6_check
.t6_eq:
    mov ecx, 1
.t6_check:
    CHECK_EQ_32 ecx, 1

    ;; ============ PUSH ES, then POP into general register ============

    TEST_CASE t7_name
    mov eax, es           ; get ES value via mov
    db 0x06               ; push es
    pop ecx               ; pop into ecx
    ; Lower 16 bits should match ES
    movzx eax, ax
    movzx ecx, cx
    cmp eax, ecx
    je .t7_eq
    mov ecx, 0
    jmp .t7_check
.t7_eq:
    mov ecx, 1
.t7_check:
    CHECK_EQ_32 ecx, 1

    ;; ============ PUSH DS, then POP into general register ============

    TEST_CASE t8_name
    mov eax, ds
    db 0x1E               ; push ds
    pop ecx
    movzx eax, ax
    movzx ecx, cx
    cmp eax, ecx
    je .t8_eq
    mov ecx, 0
    jmp .t8_check
.t8_eq:
    mov ecx, 1
.t8_check:
    CHECK_EQ_32 ecx, 1

    END_TESTS
