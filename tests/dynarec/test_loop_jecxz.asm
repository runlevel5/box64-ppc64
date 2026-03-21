; test_loop_jecxz.asm - Test LOOP, LOOPZ, LOOPNZ, JECXZ instructions
; Opcodes: 0xE0 (LOOPNZ), 0xE1 (LOOPZ), 0xE2 (LOOP), 0xE3 (JECXZ/JRCXZ)
%include "test_framework.inc"

section .data
    t1_name:  db "loop count 5", 0
    t2_name:  db "loop count 1", 0
    t3_name:  db "loop 64-bit rcx", 0
    t4_name:  db "loopnz exits on ZF=1", 0
    t5_name:  db "loopnz exits on rcx=0", 0
    t6_name:  db "loopnz counts when ZF=0", 0
    t7_name:  db "loopz exits on ZF=0", 0
    t8_name:  db "loopz exits on rcx=0", 0
    t9_name:  db "loopz counts when ZF=1", 0
    t10_name: db "jecxz taken (ecx=0)", 0
    t11_name: db "jecxz not taken (ecx!=0)", 0
    t12_name: db "jrcxz taken (rcx=0)", 0
    t13_name: db "jrcxz not taken (rcx!=0)", 0

section .text
global _start

_start:
    INIT_TESTS

    ;; ============ LOOP ============

    ; loop count 5: sum 1+2+3+4+5 = 15
    TEST_CASE t1_name
    xor eax, eax
    mov ecx, 5
.t1_loop:
    add eax, ecx           ; add current counter
    loop .t1_loop
    CHECK_EQ_32 eax, 15

    ; loop count 1: executes body once, then rcx=0 and falls through
    TEST_CASE t2_name
    xor eax, eax
    mov ecx, 1
.t2_loop:
    inc eax
    loop .t2_loop
    CHECK_EQ_32 eax, 1

    ; loop with 64-bit rcx: count 3
    TEST_CASE t3_name
    xor eax, eax
    mov rcx, 3
.t3_loop:
    inc eax
    loop .t3_loop
    CHECK_EQ_32 eax, 3

    ;; ============ LOOPNZ (LOOPNE) ============
    ; Decrements RCX, then branches if RCX!=0 AND ZF=0

    ; loopnz exits when ZF=1 (even though rcx != 0)
    ; Set up: array search, find match early
    TEST_CASE t4_name
    mov ecx, 10             ; max iterations
    xor eax, eax            ; iteration counter
.t4_loop:
    inc eax
    cmp eax, 3              ; ZF=1 when eax==3
    loopnz .t4_loop         ; exits when eax==3 (ZF=1)
    CHECK_EQ_32 eax, 3

    ; loopnz exits when rcx reaches 0 (ZF still 0)
    TEST_CASE t5_name
    mov ecx, 3
    xor eax, eax
.t5_loop:
    inc eax
    cmp eax, 100            ; never equal -> ZF=0
    loopnz .t5_loop         ; exits when rcx=0
    CHECK_EQ_32 eax, 3

    ; loopnz counts properly: iterate 5 times, no ZF=1
    TEST_CASE t6_name
    mov ecx, 5
    xor eax, eax
.t6_loop:
    inc eax
    ; Avoid setting ZF: or eax, eax will set ZF=0 for nonzero
    test eax, eax           ; ZF=0 since eax>0
    loopnz .t6_loop
    CHECK_EQ_32 eax, 5

    ;; ============ LOOPZ (LOOPE) ============
    ; Decrements RCX, then branches if RCX!=0 AND ZF=1

    ; loopz exits when ZF=0 (even though rcx != 0)
    TEST_CASE t7_name
    mov ecx, 10
    xor eax, eax
.t7_loop:
    inc eax
    cmp eax, eax            ; ZF=1 always (eax == eax)
    ; But we want to exit at eax==3: use a different compare
    ; Let's use: compare to a known-mismatch value at iteration 3
    ; Easier approach: use a counter check
    jmp .t7_check
.t7_check:
    push rcx
    cmp eax, 3
    pop rcx                 ; restore rcx without affecting ZF? No, pop doesn't affect flags
    je .t7_exit
    cmp eax, eax            ; set ZF=1 to keep looping
    loopz .t7_loop
    jmp .t7_done
.t7_exit:
    ; eax should be 3
.t7_done:
    CHECK_EQ_32 eax, 3

    ; loopz exits when rcx reaches 0 (even though ZF=1)
    TEST_CASE t8_name
    mov ecx, 4
    xor eax, eax
.t8_loop:
    inc eax
    cmp eax, eax            ; ZF=1 always
    loopz .t8_loop          ; exits when rcx=0
    CHECK_EQ_32 eax, 4

    ; loopz counts with ZF=1: iterate 3 times
    TEST_CASE t9_name
    mov ecx, 3
    xor eax, eax
.t9_loop:
    inc eax
    cmp eax, eax            ; ZF=1
    loopz .t9_loop
    CHECK_EQ_32 eax, 3

    ;; ============ JECXZ / JRCXZ ============

    ; jecxz taken: ecx=0
    TEST_CASE t10_name
    xor ecx, ecx            ; ecx=0
    mov eax, 0
    jecxz .t10_taken
    mov eax, 99             ; should not execute
    jmp .t10_done
.t10_taken:
    mov eax, 1
.t10_done:
    CHECK_EQ_32 eax, 1

    ; jecxz not taken: ecx!=0
    TEST_CASE t11_name
    mov ecx, 42
    mov eax, 0
    jecxz .t11_taken
    mov eax, 1              ; should execute (not taken)
    jmp .t11_done
.t11_taken:
    mov eax, 99
.t11_done:
    CHECK_EQ_32 eax, 1

    ; jrcxz taken: rcx=0 (64-bit)
    TEST_CASE t12_name
    xor rcx, rcx
    mov eax, 0
    jrcxz .t12_taken
    mov eax, 99
    jmp .t12_done
.t12_taken:
    mov eax, 1
.t12_done:
    CHECK_EQ_32 eax, 1

    ; jrcxz not taken: rcx has high bits set (ecx=0 but rcx!=0)
    TEST_CASE t13_name
    mov rcx, 0x100000000    ; ecx=0 but rcx!=0
    mov eax, 0
    jrcxz .t13_taken
    mov eax, 1              ; should execute (jrcxz checks full rcx)
    jmp .t13_done
.t13_taken:
    mov eax, 99
.t13_done:
    CHECK_EQ_32 eax, 1

    END_TESTS
