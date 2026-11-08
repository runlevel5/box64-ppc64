; test_sse_horiz.asm - Test SSE3 horizontal add/sub and ADDSUBPS/PD
; Covers: HADDPS (F2 0F 7C), HADDPD (66 0F 7C), HSUBPS (F2 0F 7D),
;         HSUBPD (66 0F 7D), ADDSUBPS (F2 0F D0), ADDSUBPD (66 0F D0)
%include "test_framework.inc"

section .data
    align 16
    ; HADDPS test data: [1.0, 2.0, 3.0, 4.0] and [5.0, 6.0, 7.0, 8.0]
    haddps_a: dd 1.0, 2.0, 3.0, 4.0
    haddps_b: dd 5.0, 6.0, 7.0, 8.0
    ; Expected: [1+2, 3+4, 5+6, 7+8] = [3.0, 7.0, 11.0, 15.0]
    haddps_exp: dd 3.0, 7.0, 11.0, 15.0

    ; HSUBPS test data
    hsubps_a: dd 10.0, 3.0, 20.0, 5.0
    hsubps_b: dd 100.0, 1.0, 50.0, 2.0
    ; Expected: [10-3, 20-5, 100-1, 50-2] = [7.0, 15.0, 99.0, 48.0]
    hsubps_exp: dd 7.0, 15.0, 99.0, 48.0

    ; HADDPD test data: [1.0, 2.0] and [3.0, 4.0]
    align 16
    haddpd_a: dq 1.0, 2.0
    haddpd_b: dq 3.0, 4.0
    ; Expected: [1+2, 3+4] = [3.0, 7.0]
    haddpd_exp: dq 3.0, 7.0

    ; HSUBPD test data: [10.0, 3.0] and [20.0, 5.0]
    align 16
    hsubpd_a: dq 10.0, 3.0
    hsubpd_b: dq 20.0, 5.0
    ; Expected: [10-3, 20-5] = [7.0, 15.0]
    hsubpd_exp: dq 7.0, 15.0

    ; ADDSUBPS test data: [1.0, 2.0, 3.0, 4.0] and [0.5, 0.5, 0.5, 0.5]
    align 16
    addsubps_a: dd 1.0, 2.0, 3.0, 4.0
    addsubps_b: dd 0.5, 0.5, 0.5, 0.5
    ; Expected: [1-0.5, 2+0.5, 3-0.5, 4+0.5] = [0.5, 2.5, 2.5, 4.5]
    addsubps_exp: dd 0.5, 2.5, 2.5, 4.5

    ; ADDSUBPD test data: [1.0, 2.0] and [0.5, 0.5]
    align 16
    addsubpd_a: dq 1.0, 2.0
    addsubpd_b: dq 0.5, 0.5
    ; Expected: [1-0.5, 2+0.5] = [0.5, 2.5]
    addsubpd_exp: dq 0.5, 2.5

    ; Additional edge cases
    align 16
    haddps_neg: dd -1.0, 1.0, -2.0, 2.0
    ; Expected: [-1+1, -2+2, ...] = [0.0, 0.0, ...]
    haddps_neg_exp: dd 0.0, 0.0, 0.0, 0.0
    haddps_self_exp: dd 0.0, 0.0, 0.0, 0.0

    t1_name:  db "haddps basic", 0
    t2_name:  db "hsubps basic", 0
    t3_name:  db "haddpd basic", 0
    t4_name:  db "hsubpd basic", 0
    t5_name:  db "addsubps basic", 0
    t6_name:  db "addsubpd basic", 0
    t7_name:  db "haddps self (a,a)", 0
    t8_name:  db "haddps negative cancel", 0
    t9_name:  db "hsubps self (a,a) = 0", 0
    t10_name: db "haddpd self (a,a)", 0
    t11_name: db "hsubpd self (a,a) = 0", 0
    t12_name: db "addsubps neg values", 0

    ; For self-hadd of [1,2,3,4]: [1+2, 3+4, 1+2, 3+4] = [3,7,3,7]
    align 16
    haddps_self_a: dd 1.0, 2.0, 3.0, 4.0
    haddps_self_exp2: dd 3.0, 7.0, 3.0, 7.0

    ; haddpd self of [1,2]: [1+2, 1+2] = [3, 3]
    align 16
    haddpd_self_a: dq 1.0, 2.0
    haddpd_self_exp: dq 3.0, 3.0

    ; addsubps neg: [-1, -2, -3, -4] and [1, 1, 1, 1]
    ; Expected: [-1-1, -2+1, -3-1, -4+1] = [-2, -1, -4, -3]
    align 16
    addsubps_neg_a: dd -1.0, -2.0, -3.0, -4.0
    addsubps_neg_b: dd 1.0, 1.0, 1.0, 1.0
    addsubps_neg_exp: dd -2.0, -1.0, -4.0, -3.0

section .bss
    alignb 16
    result: resb 16

section .text
global _start

_start:
    INIT_TESTS

    ; ==== Test 1: HADDPS basic ====
    ; haddps xmm0, xmm1: xmm0=[a0+a1, a2+a3, b0+b1, b2+b3]
    TEST_CASE t1_name
    movaps xmm0, [rel haddps_a]
    movaps xmm1, [rel haddps_b]
    haddps xmm0, xmm1
    movaps [rel result], xmm0
    movaps xmm1, [rel haddps_exp]
    ; Compare low 64 bits
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t1_fail
    ; Compare high 64 bits
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t1_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t1_done
.t1_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t1_done:

    ; ==== Test 2: HSUBPS basic ====
    TEST_CASE t2_name
    movaps xmm0, [rel hsubps_a]
    movaps xmm1, [rel hsubps_b]
    hsubps xmm0, xmm1
    movaps xmm1, [rel hsubps_exp]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t2_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t2_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t2_done
.t2_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t2_done:

    ; ==== Test 3: HADDPD basic ====
    TEST_CASE t3_name
    movapd xmm0, [rel haddpd_a]
    movapd xmm1, [rel haddpd_b]
    haddpd xmm0, xmm1
    movapd xmm1, [rel haddpd_exp]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t3_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t3_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t3_done
.t3_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t3_done:

    ; ==== Test 4: HSUBPD basic ====
    TEST_CASE t4_name
    movapd xmm0, [rel hsubpd_a]
    movapd xmm1, [rel hsubpd_b]
    hsubpd xmm0, xmm1
    movapd xmm1, [rel hsubpd_exp]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t4_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t4_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t4_done
.t4_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t4_done:

    ; ==== Test 5: ADDSUBPS basic ====
    ; addsubps: even elements subtract, odd elements add
    TEST_CASE t5_name
    movaps xmm0, [rel addsubps_a]
    movaps xmm1, [rel addsubps_b]
    addsubps xmm0, xmm1
    movaps xmm1, [rel addsubps_exp]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t5_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t5_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t5_done
.t5_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t5_done:

    ; ==== Test 6: ADDSUBPD basic ====
    TEST_CASE t6_name
    movapd xmm0, [rel addsubpd_a]
    movapd xmm1, [rel addsubpd_b]
    addsubpd xmm0, xmm1
    movapd xmm1, [rel addsubpd_exp]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t6_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t6_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t6_done
.t6_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t6_done:

    ; ==== Test 7: HADDPS self (a,a) ====
    ; [1,2,3,4] hadd [1,2,3,4] = [1+2, 3+4, 1+2, 3+4] = [3,7,3,7]
    TEST_CASE t7_name
    movaps xmm0, [rel haddps_self_a]
    movaps xmm1, xmm0
    haddps xmm0, xmm1
    movaps xmm1, [rel haddps_self_exp2]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t7_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t7_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t7_done
.t7_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t7_done:

    ; ==== Test 8: HADDPS negative cancel ====
    ; [-1, 1, -2, 2] hadd [-1, 1, -2, 2] = [0, 0, 0, 0]
    TEST_CASE t8_name
    movaps xmm0, [rel haddps_neg]
    movaps xmm1, xmm0
    haddps xmm0, xmm1
    ; All should be zero
    pxor xmm1, xmm1
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t8_fail
    psrldq xmm0, 8
    movq rax, xmm0
    cmp rax, rbx
    jne .t8_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t8_done
.t8_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t8_done:

    ; ==== Test 9: HSUBPS self = all zeros ====
    ; hsubps xmm, xmm: [a0-a1, a2-a3, a0-a1, a2-a3]
    ; For [1,1,1,1]: [0,0,0,0]
    TEST_CASE t9_name
    movaps xmm0, [rel addsubps_b]   ; [0.5, 0.5, 0.5, 0.5] - doesn't matter, use equal pairs
    ; Actually let's use a clean approach
    pcmpeqd xmm0, xmm0             ; all 1s
    psrld xmm0, 25                   ; 0x7F = 127 in each dword
    ; Better: load known equal-pair values
    movaps xmm0, [rel haddps_a]     ; [1,2,3,4]
    hsubps xmm0, xmm0               ; [1-2, 3-4, 1-2, 3-4] = [-1, -1, -1, -1]
    ; Check that all 4 floats are -1.0
    ; -1.0f = 0xBF800000, as packed = 0xBF800000BF800000 (low64)
    movq rax, xmm0
    mov rbx, 0xBF800000BF800000
    cmp rax, rbx
    jne .t9_fail
    psrldq xmm0, 8
    movq rax, xmm0
    cmp rax, rbx
    jne .t9_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t9_done
.t9_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t9_done:

    ; ==== Test 10: HADDPD self ====
    ; [1, 2] hadd [1, 2] = [1+2, 1+2] = [3, 3]
    TEST_CASE t10_name
    movapd xmm0, [rel haddpd_self_a]
    movapd xmm1, xmm0
    haddpd xmm0, xmm1
    movapd xmm1, [rel haddpd_self_exp]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t10_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t10_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t10_done
.t10_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t10_done:

    ; ==== Test 11: HSUBPD self = all zeros ====
    ; [1, 2] hsub [1, 2] = [1-2, 1-2] = [-1, -1]
    TEST_CASE t11_name
    movapd xmm0, [rel haddpd_self_a]
    movapd xmm1, xmm0
    hsubpd xmm0, xmm1
    ; -1.0d = 0xBFF0000000000000
    mov rax, 0xBFF0000000000000
    movq rbx, xmm0
    cmp rax, rbx
    jne .t11_fail
    psrldq xmm0, 8
    movq rbx, xmm0
    cmp rax, rbx
    jne .t11_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t11_done
.t11_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t11_done:

    ; ==== Test 12: ADDSUBPS with negatives ====
    TEST_CASE t12_name
    movaps xmm0, [rel addsubps_neg_a]
    movaps xmm1, [rel addsubps_neg_b]
    addsubps xmm0, xmm1
    movaps xmm1, [rel addsubps_neg_exp]
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t12_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t12_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t12_done
.t12_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t12_done:

    END_TESTS
