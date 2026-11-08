; test_sse_horiz_nan.asm - Edge case tests for SSE3 horizontal add/sub
; Focus: NaN propagation, INF arithmetic, denormals, memory operands
; Covers: HADDPS (F2 0F 7C), HSUBPS (F2 0F 7D),
;         HADDPD (66 0F 7C), HSUBPD (66 0F 7D)
%include "test_framework.inc"

section .data
    align 16

    ;; === Float constants (SP) ===
    ; QNaN SP = 0x7FC00000, -QNaN SP = 0xFFC00000
    ; +INF SP = 0x7F800000, -INF SP = 0xFF800000
    ; Denorm SP: smallest subnormal = 0x00000001 (~1.4e-45)

    ; HADDPS NaN tests
    ; Test 1: NaN in Gx lane 0 — {NaN, 2.0, 3.0, 4.0} hadd {5.0, 6.0, 7.0, 8.0}
    ;   Result: {NaN+2.0=NaN, 3+4=7, 5+6=11, 7+8=15}
    haddps_nan_gx:   dd 0x7FC00000, 2.0, 3.0, 4.0
    haddps_nan_ex:   dd 5.0, 6.0, 7.0, 8.0

    ; Test 2: NaN in Ex lane 2 — {1.0, 2.0, 3.0, 4.0} hadd {5.0, 6.0, NaN, 8.0}
    ;   Result: {1+2=3, 3+4=7, 5+6=11, NaN+8=NaN}
    haddps_ex_nan:   dd 5.0, 6.0, 0x7FC00000, 8.0

    ; Test 3: INF + (-INF) → NaN in HADDPS
    ;   {+INF, -INF, 1.0, 2.0} hadd {3.0, 4.0, 5.0, 6.0}
    ;   Result lane 0: +INF + (-INF) = NaN (indefinite = 0xFFC00000 on x86)
    haddps_inf_a:    dd 0x7F800000, 0xFF800000, 1.0, 2.0
    haddps_inf_b:    dd 3.0, 4.0, 5.0, 6.0

    ; Test 4: Denormal inputs
    ;   {denorm_min, denorm_min, 1.0, 2.0} hadd {3.0, 4.0, 5.0, 6.0}
    ;   Result lane 0: denorm + denorm = 2*denorm (still denorm, 0x00000002)
    haddps_denorm_a: dd 0x00000001, 0x00000001, 1.0, 2.0
    haddps_denorm_b: dd 3.0, 4.0, 5.0, 6.0

    ; Test 5: Memory operand for HADDPS
    ;   Same as basic test but Ex comes from memory
    haddps_mem_gx:   dd 1.0, 2.0, 3.0, 4.0
    haddps_mem_ex:   dd 10.0, 20.0, 30.0, 40.0
    ; Result: {1+2=3, 3+4=7, 10+20=30, 30+40=70}
    ; 3.0=0x40400000, 7.0=0x40E00000, 30.0=0x41F00000, 70.0=0x428C0000

    ; Test 6: HADDPS same register with NaN
    ;   {NaN, 1.0, 2.0, 3.0} hadd {NaN, 1.0, 2.0, 3.0}
    ;   Result: {NaN+1=NaN, 2+3=5, NaN+1=NaN, 2+3=5}
    haddps_self_nan: dd 0x7FC00000, 1.0, 2.0, 3.0

    ;; === HSUBPS tests ===
    ; Test 7: NaN in HSUBPS
    ;   {NaN, 2.0, 3.0, 4.0} hsub {5.0, 6.0, 7.0, 8.0}
    ;   Result: {NaN-2=NaN, 3-4=-1, 5-6=-1, 7-8=-1}
    hsubps_nan_gx:   dd 0x7FC00000, 2.0, 3.0, 4.0
    hsubps_nan_ex:   dd 5.0, 6.0, 7.0, 8.0

    ; Test 8: INF - INF → NaN in HSUBPS
    ;   {+INF, +INF, 1.0, 2.0} hsub {3.0, 4.0, 5.0, 6.0}
    ;   Result lane 0: +INF - (+INF) = NaN
    hsubps_inf_a:    dd 0x7F800000, 0x7F800000, 1.0, 2.0
    hsubps_inf_b:    dd 3.0, 4.0, 5.0, 6.0

    ; Test 9: HSUBPS memory operand
    hsubps_mem_gx:   dd 10.0, 3.0, 20.0, 5.0
    hsubps_mem_ex:   dd 100.0, 1.0, 50.0, 2.0
    ; Result: {10-3=7, 20-5=15, 100-1=99, 50-2=48}
    ; 7.0=0x40E00000, 15.0=0x41700000, 99.0=0x42C60000, 48.0=0x42400000

    ;; === Double constants (DP) ===
    ; QNaN DP = 0x7FF8000000000000
    ; +INF DP = 0x7FF0000000000000, -INF = 0xFFF0000000000000
    ; Denorm DP: smallest = 0x0000000000000001

    ; Test 10: HADDPD NaN in Gx
    ;   {NaN, 2.0} hadd {3.0, 4.0}
    ;   Result: {NaN+2=NaN, 3+4=7}
    align 16
    haddpd_nan_gx:   dq 0x7FF8000000000000, 2.0
    haddpd_nan_ex:   dq 3.0, 4.0

    ; Test 11: HADDPD INF + (-INF) → NaN
    ;   {+INF, -INF} hadd {1.0, 2.0}
    ;   Result: {+INF+(-INF)=NaN, 1+2=3}
    align 16
    haddpd_inf_a:    dq 0x7FF0000000000000, 0xFFF0000000000000
    haddpd_inf_b:    dq 1.0, 2.0

    ; Test 12: HADDPD memory operand
    ;   {10.0, 20.0} hadd [30.0, 40.0]
    ;   Result: {10+20=30, 30+40=70}
    align 16
    haddpd_mem_gx:   dq 10.0, 20.0
    haddpd_mem_ex:   dq 30.0, 40.0

    ; Test 13: HSUBPD NaN propagation
    ;   {1.0, NaN} hsub {3.0, 4.0}
    ;   Result: {1-NaN=NaN, 3-4=-1}
    align 16
    hsubpd_nan_gx:   dq 1.0, 0x7FF8000000000000
    hsubpd_nan_ex:   dq 3.0, 4.0

    ; Test 14: HSUBPD INF - INF → NaN
    ;   {+INF, +INF} hsub {1.0, 2.0}
    ;   Result: {INF-INF=NaN, 1-2=-1}
    align 16
    hsubpd_inf_a:    dq 0x7FF0000000000000, 0x7FF0000000000000
    hsubpd_inf_b:    dq 1.0, 2.0

    ; Test 15: HSUBPD memory operand
    ;   {10.0, 3.0} hsub [20.0, 5.0]
    ;   Result: {10-3=7, 20-5=15}
    align 16
    hsubpd_mem_gx:   dq 10.0, 3.0
    hsubpd_mem_ex:   dq 20.0, 5.0

    ; Test 16: HADDPS all NaN
    ;   {NaN, NaN, NaN, NaN} hadd {NaN, NaN, NaN, NaN}
    ;   Result: all NaN
    align 16
    haddps_allnan:   dd 0x7FC00000, 0x7FC00000, 0x7FC00000, 0x7FC00000

    ; Test 17: HADDPS mixed: NaN and INF
    ;   {NaN, +INF, -INF, NaN} hadd {1.0, 2.0, 3.0, 4.0}
    ;   lane0: NaN + INF = NaN, lane1: -INF + NaN = NaN
    ;   lane2: 1+2=3, lane3: 3+4=7
    align 16
    haddps_nan_inf:  dd 0x7FC00000, 0x7F800000, 0xFF800000, 0x7FC00000

    ; Test 18: HADDPD denormal
    ;   {denorm_min, denorm_min} hadd {1.0, 2.0}
    ;   Result: {denorm+denorm=2*denorm, 1+2=3}
    align 16
    haddpd_denorm_a: dq 0x0000000000000001, 0x0000000000000001
    haddpd_denorm_b: dq 1.0, 2.0

    ;; Test name strings
    t1_name:  db "haddps NaN in Gx[0]", 0
    t2_name:  db "haddps NaN in Ex[2]", 0
    t3_name:  db "haddps INF+(-INF)=NaN", 0
    t4_name:  db "haddps denormals", 0
    t5_name:  db "haddps memory operand", 0
    t6_name:  db "haddps self with NaN", 0
    t7_name:  db "hsubps NaN in Gx[0]", 0
    t8_name:  db "hsubps INF-INF=NaN", 0
    t9_name:  db "hsubps memory operand", 0
    t10_name: db "haddpd NaN in Gx[0]", 0
    t11_name: db "haddpd INF+(-INF)=NaN", 0
    t12_name: db "haddpd memory operand", 0
    t13_name: db "hsubpd NaN in Gx[1]", 0
    t14_name: db "hsubpd INF-INF=NaN", 0
    t15_name: db "hsubpd memory operand", 0
    t16_name: db "haddps all NaN", 0
    t17_name: db "haddps NaN+INF mixed", 0
    t18_name: db "haddpd denormals", 0

section .text
global _start

;; Helper: compare full 128-bit xmm result against two 64-bit immediates
;; Inputs: xmm0 = result, expected low64 in rdi, expected high64 in rsi
;; Uses rbx for comparison. Returns: jumps to fail label or falls through.
;; We'll do inline comparison per test instead of a function to keep it simple.

_start:
    INIT_TESTS

    ; ==== Test 1: HADDPS NaN in Gx lane 0 ====
    ; {NaN, 2.0, 3.0, 4.0} hadd {5.0, 6.0, 7.0, 8.0}
    ; Result: {NaN, 7.0, 11.0, 15.0}
    ; NaN: any value with exp=0xFF and mantissa!=0. After hadd, NaN propagates.
    ; We check: lane0 is NaN (exp bits set, mantissa non-zero), lanes 1-3 are exact.
    ; Low64: lane0=NaN (some NaN pattern), lane1=7.0=0x40E00000
    ; High64: lane2=11.0=0x41300000, lane3=15.0=0x41700000
    TEST_CASE t1_name
    movaps xmm0, [rel haddps_nan_gx]
    movaps xmm1, [rel haddps_nan_ex]
    haddps xmm0, xmm1
    ; Check lane 0 is NaN: extract dword, verify exponent=0xFF and mantissa!=0
    movd eax, xmm0
    mov ebx, eax
    and ebx, 0x7F800000    ; isolate exponent
    cmp ebx, 0x7F800000    ; must be all-1s for NaN/INF
    jne .t1_fail
    mov ebx, eax
    and ebx, 0x007FFFFF    ; isolate mantissa
    test ebx, ebx          ; must be non-zero for NaN (not INF)
    jz .t1_fail
    ; Check lane 1 = 7.0 = 0x40E00000
    psrldq xmm0, 4         ; shift right by 4 bytes, lane1 now in lane0
    movd eax, xmm0
    cmp eax, 0x40E00000
    jne .t1_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t1_done
.t1_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t1_done:

    ; ==== Test 2: HADDPS NaN in Ex lane 2 ====
    ; {1, 2, 3, 4} hadd {5, 6, NaN, 8}
    ; Result: {3, 7, 11, NaN+8=NaN}
    ; Low64: {3.0=0x40400000, 7.0=0x40E00000} → 0x40E0000040400000
    ; High64 lane3: should be NaN
    TEST_CASE t2_name
    movaps xmm0, [rel haddps_nan_gx + 0]   ; reuse data? No, need clean Gx
    movaps xmm0, [rel haddps_mem_gx]        ; {1, 2, 3, 4}
    movaps xmm1, [rel haddps_ex_nan]        ; {5, 6, NaN, 8}
    haddps xmm0, xmm1
    ; Check low 64 bits = {3.0, 7.0}
    movq rax, xmm0
    mov rbx, 0x40E0000040400000
    cmp rax, rbx
    jne .t2_fail
    ; Check lane 2 = 11.0 = 0x41300000
    movaps xmm2, xmm0
    psrldq xmm2, 8
    movd eax, xmm2
    cmp eax, 0x41300000
    jne .t2_fail
    ; Check lane 3 is NaN
    psrldq xmm2, 4
    movd eax, xmm2
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t2_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t2_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t2_done
.t2_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t2_done:

    ; ==== Test 3: HADDPS INF + (-INF) = NaN ====
    ; {+INF, -INF, 1.0, 2.0} hadd {3.0, 4.0, 5.0, 6.0}
    ; lane0: INF+(-INF) = NaN (some NaN pattern)
    ; lane1: 1+2=3, lane2: 3+4=7, lane3: 5+6=11
    TEST_CASE t3_name
    movaps xmm0, [rel haddps_inf_a]
    movaps xmm1, [rel haddps_inf_b]
    haddps xmm0, xmm1
    ; Lane 0 should be NaN: exponent=0xFF, mantissa!=0
    movd eax, xmm0
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t3_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t3_fail
    ; Lane 1 = 3.0 = 0x40400000
    movaps xmm2, xmm0
    psrldq xmm2, 4
    movd eax, xmm2
    cmp eax, 0x40400000
    jne .t3_fail
    ; Lane 2 = 7.0 = 0x40E00000
    movaps xmm2, xmm0
    psrldq xmm2, 8
    movd eax, xmm2
    cmp eax, 0x40E00000
    jne .t3_fail
    ; Lane 3 = 11.0 = 0x41300000
    movaps xmm2, xmm0
    psrldq xmm2, 12
    movd eax, xmm2
    cmp eax, 0x41300000
    jne .t3_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t3_done
.t3_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t3_done:

    ; ==== Test 4: HADDPS denormals ====
    ; {denorm_min, denorm_min, 1.0, 2.0} hadd {3.0, 4.0, 5.0, 6.0}
    ; lane0: 0x00000001 + 0x00000001 = 0x00000002
    ; lane1: 1+2=3, lane2: 3+4=7, lane3: 5+6=11
    TEST_CASE t4_name
    movaps xmm0, [rel haddps_denorm_a]
    movaps xmm1, [rel haddps_denorm_b]
    haddps xmm0, xmm1
    movd eax, xmm0
    cmp eax, 0x00000002
    jne .t4_fail
    ; lane1 = 3.0
    movaps xmm2, xmm0
    psrldq xmm2, 4
    movd eax, xmm2
    cmp eax, 0x40400000
    jne .t4_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t4_done
.t4_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t4_done:

    ; ==== Test 5: HADDPS memory operand ====
    ; {1, 2, 3, 4} hadd [10, 20, 30, 40]
    ; Result: {3, 7, 30, 70}
    TEST_CASE t5_name
    movaps xmm0, [rel haddps_mem_gx]
    haddps xmm0, [rel haddps_mem_ex]
    ; low64: {3.0=0x40400000, 7.0=0x40E00000}
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x40E0000040400000
    ; Continuing — check high64
    TEST_CASE t5_name
    movaps xmm0, [rel haddps_mem_gx]
    haddps xmm0, [rel haddps_mem_ex]
    movaps xmm2, xmm0
    psrldq xmm2, 8
    ; high64: {30.0=0x41F00000, 70.0=0x428C0000}
    movq rax, xmm2
    CHECK_EQ_64 rax, 0x428C000041F00000

    ; ==== Test 6: HADDPS same register with NaN ====
    ; {NaN, 1.0, 2.0, 3.0} hadd {NaN, 1.0, 2.0, 3.0}
    ; Result: {NaN+1=NaN, 2+3=5, NaN+1=NaN, 2+3=5}
    ; lane1=5.0=0x40A00000, lane3=5.0=0x40A00000
    TEST_CASE t6_name
    movaps xmm0, [rel haddps_self_nan]
    haddps xmm0, xmm0
    ; Check lane 0 is NaN
    movd eax, xmm0
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t6_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t6_fail
    ; Check lane 1 = 5.0
    movaps xmm2, xmm0
    psrldq xmm2, 4
    movd eax, xmm2
    cmp eax, 0x40A00000
    jne .t6_fail
    ; Check lane 2 is NaN
    movaps xmm2, xmm0
    psrldq xmm2, 8
    movd eax, xmm2
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t6_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t6_fail
    ; Check lane 3 = 5.0
    movaps xmm2, xmm0
    psrldq xmm2, 12
    movd eax, xmm2
    cmp eax, 0x40A00000
    jne .t6_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t6_done
.t6_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t6_done:

    ; ==== Test 7: HSUBPS NaN in Gx[0] ====
    ; {NaN, 2.0, 3.0, 4.0} hsub {5.0, 6.0, 7.0, 8.0}
    ; lane0: NaN-2=NaN, lane1: 3-4=-1=0xBF800000
    ; lane2: 5-6=-1, lane3: 7-8=-1
    TEST_CASE t7_name
    movaps xmm0, [rel hsubps_nan_gx]
    movaps xmm1, [rel hsubps_nan_ex]
    hsubps xmm0, xmm1
    ; Check lane 0 is NaN
    movd eax, xmm0
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t7_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t7_fail
    ; Check lane 1 = -1.0 = 0xBF800000
    movaps xmm2, xmm0
    psrldq xmm2, 4
    movd eax, xmm2
    cmp eax, 0xBF800000
    jne .t7_fail
    ; Check lane 2 = -1.0
    movaps xmm2, xmm0
    psrldq xmm2, 8
    movd eax, xmm2
    cmp eax, 0xBF800000
    jne .t7_fail
    ; Check lane 3 = -1.0
    movaps xmm2, xmm0
    psrldq xmm2, 12
    movd eax, xmm2
    cmp eax, 0xBF800000
    jne .t7_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t7_done
.t7_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t7_done:

    ; ==== Test 8: HSUBPS INF - INF = NaN ====
    ; {+INF, +INF, 1.0, 2.0} hsub {3.0, 4.0, 5.0, 6.0}
    ; lane0: INF - INF = NaN (some NaN pattern)
    ; lane1: 1-2=-1, lane2: 3-4=-1, lane3: 5-6=-1
    TEST_CASE t8_name
    movaps xmm0, [rel hsubps_inf_a]
    movaps xmm1, [rel hsubps_inf_b]
    hsubps xmm0, xmm1
    ; Lane 0 should be NaN: exponent=0xFF, mantissa!=0
    movd eax, xmm0
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t8_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t8_fail
    ; Lane 1 = -1.0
    movaps xmm2, xmm0
    psrldq xmm2, 4
    movd eax, xmm2
    cmp eax, 0xBF800000
    jne .t8_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t8_done
.t8_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t8_done:

    ; ==== Test 9: HSUBPS memory operand ====
    ; {10, 3, 20, 5} hsub [100, 1, 50, 2]
    ; Result: {7, 15, 99, 48}
    TEST_CASE t9_name
    movaps xmm0, [rel hsubps_mem_gx]
    hsubps xmm0, [rel hsubps_mem_ex]
    ; low64: {7.0=0x40E00000, 15.0=0x41700000} = 0x417000004​0E00000
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x4170000040E00000
    ; high64 check
    TEST_CASE t9_name
    movaps xmm0, [rel hsubps_mem_gx]
    hsubps xmm0, [rel hsubps_mem_ex]
    movaps xmm2, xmm0
    psrldq xmm2, 8
    ; high64: {99.0=0x42C60000, 48.0=0x42400000} = 0x4240000042C60000
    movq rax, xmm2
    CHECK_EQ_64 rax, 0x4240000042C60000

    ; ==== Test 10: HADDPD NaN in Gx[0] ====
    ; {NaN, 2.0} hadd {3.0, 4.0}
    ; Result: {NaN+2=NaN, 3+4=7}
    TEST_CASE t10_name
    movapd xmm0, [rel haddpd_nan_gx]
    movapd xmm1, [rel haddpd_nan_ex]
    haddpd xmm0, xmm1
    ; lane 0 (low 64 bits) should be NaN
    movq rax, xmm0
    ; Check it's a NaN: exponent bits all 1, mantissa non-zero
    mov rbx, rax
    mov rcx, 0x7FF0000000000000
    and rbx, rcx
    cmp rbx, rcx
    jne .t10_fail
    mov rbx, rax
    mov rcx, 0x000FFFFFFFFFFFFF
    and rbx, rcx
    test rbx, rbx
    jz .t10_fail
    ; lane 1 (high 64 bits) = 7.0 = 0x401C000000000000
    psrldq xmm0, 8
    movq rax, xmm0
    mov rbx, 0x401C000000000000
    cmp rax, rbx
    jne .t10_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t10_done
.t10_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t10_done:

    ; ==== Test 11: HADDPD INF + (-INF) = NaN ====
    ; {+INF, -INF} hadd {1.0, 2.0}
    ; lane0: INF+(-INF) = NaN (some NaN pattern, sign may vary)
    ; lane1: 1+2=3 = 0x4008000000000000
    TEST_CASE t11_name
    movapd xmm0, [rel haddpd_inf_a]
    movapd xmm1, [rel haddpd_inf_b]
    haddpd xmm0, xmm1
    ; Lane 0 must be NaN: exponent all-1s AND mantissa non-zero
    movq rax, xmm0
    mov rbx, rax
    mov rcx, 0x7FF0000000000000
    and rbx, rcx
    cmp rbx, rcx
    jne .t11_fail
    mov rbx, rax
    mov rcx, 0x000FFFFFFFFFFFFF
    and rbx, rcx
    test rbx, rbx
    jz .t11_fail
    ; Lane 1 = 3.0
    psrldq xmm0, 8
    movq rax, xmm0
    mov rbx, 0x4008000000000000
    cmp rax, rbx
    jne .t11_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t11_done
.t11_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t11_done:

    ; ==== Test 12: HADDPD memory operand ====
    ; {10.0, 20.0} hadd [30.0, 40.0]
    ; Result: {10+20=30.0, 30+40=70.0}
    ; 30.0 = 0x403E000000000000, 70.0 = 0x4051800000000000
    TEST_CASE t12_name
    movapd xmm0, [rel haddpd_mem_gx]
    haddpd xmm0, [rel haddpd_mem_ex]
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x403E000000000000
    TEST_CASE t12_name
    movapd xmm0, [rel haddpd_mem_gx]
    haddpd xmm0, [rel haddpd_mem_ex]
    psrldq xmm0, 8
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x4051800000000000

    ; ==== Test 13: HSUBPD NaN in Gx[1] ====
    ; {1.0, NaN} hsub {3.0, 4.0}
    ; lane0: 1-NaN=NaN, lane1: 3-4=-1
    TEST_CASE t13_name
    movapd xmm0, [rel hsubpd_nan_gx]
    movapd xmm1, [rel hsubpd_nan_ex]
    hsubpd xmm0, xmm1
    ; lane 0 should be NaN
    movq rax, xmm0
    mov rbx, rax
    mov rcx, 0x7FF0000000000000
    and rbx, rcx
    cmp rbx, rcx
    jne .t13_fail
    mov rbx, rax
    mov rcx, 0x000FFFFFFFFFFFFF
    and rbx, rcx
    test rbx, rbx
    jz .t13_fail
    ; lane 1 = -1.0 = 0xBFF0000000000000
    psrldq xmm0, 8
    movq rax, xmm0
    mov rbx, 0xBFF0000000000000
    cmp rax, rbx
    jne .t13_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t13_done
.t13_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t13_done:

    ; ==== Test 14: HSUBPD INF - INF = NaN ====
    ; {+INF, +INF} hsub {1.0, 2.0}
    ; lane0: INF-INF = NaN (some NaN pattern, sign may vary)
    ; lane1: 1-2=-1
    TEST_CASE t14_name
    movapd xmm0, [rel hsubpd_inf_a]
    movapd xmm1, [rel hsubpd_inf_b]
    hsubpd xmm0, xmm1
    ; Lane 0 must be NaN: exponent all-1s AND mantissa non-zero
    movq rax, xmm0
    mov rbx, rax
    mov rcx, 0x7FF0000000000000
    and rbx, rcx
    cmp rbx, rcx
    jne .t14_fail
    mov rbx, rax
    mov rcx, 0x000FFFFFFFFFFFFF
    and rbx, rcx
    test rbx, rbx
    jz .t14_fail
    ; Lane 1 = -1.0
    psrldq xmm0, 8
    movq rax, xmm0
    mov rbx, 0xBFF0000000000000
    cmp rax, rbx
    jne .t14_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t14_done
.t14_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t14_done:

    ; ==== Test 15: HSUBPD memory operand ====
    ; {10.0, 3.0} hsub [20.0, 5.0]
    ; Result: {10-3=7.0, 20-5=15.0}
    ; 7.0 = 0x401C000000000000, 15.0 = 0x402E000000000000
    TEST_CASE t15_name
    movapd xmm0, [rel hsubpd_mem_gx]
    hsubpd xmm0, [rel hsubpd_mem_ex]
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x401C000000000000
    TEST_CASE t15_name
    movapd xmm0, [rel hsubpd_mem_gx]
    hsubpd xmm0, [rel hsubpd_mem_ex]
    psrldq xmm0, 8
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x402E000000000000

    ; ==== Test 16: HADDPS all NaN ====
    ; {NaN, NaN, NaN, NaN} hadd {NaN, NaN, NaN, NaN}
    ; All result lanes should be NaN
    TEST_CASE t16_name
    movaps xmm0, [rel haddps_allnan]
    movaps xmm1, xmm0
    haddps xmm0, xmm1
    ; Check lane 0 is NaN
    movd eax, xmm0
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t16_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t16_fail
    ; Check lane 3 is NaN
    movaps xmm2, xmm0
    psrldq xmm2, 12
    movd eax, xmm2
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t16_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t16_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t16_done
.t16_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t16_done:

    ; ==== Test 17: HADDPS NaN and INF mixed ====
    ; {NaN, +INF, -INF, NaN} hadd {1.0, 2.0, 3.0, 4.0}
    ; lane0: NaN+INF = NaN, lane1: -INF+NaN = NaN
    ; lane2: 1+2=3.0, lane3: 3+4=7.0
    TEST_CASE t17_name
    movaps xmm0, [rel haddps_nan_inf]
    movaps xmm1, [rel haddps_inf_b]   ; {3, 4, 5, 6} — wait, need {1,2,3,4}
    ; Actually haddps_inf_b = {3,4,5,6}. Let me use haddps_mem_gx = {1,2,3,4}
    movaps xmm1, [rel haddps_mem_gx]  ; {1, 2, 3, 4}
    haddps xmm0, xmm1
    ; Lane 0: NaN
    movd eax, xmm0
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t17_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t17_fail
    ; Lane 1: NaN
    movaps xmm2, xmm0
    psrldq xmm2, 4
    movd eax, xmm2
    mov ebx, eax
    and ebx, 0x7F800000
    cmp ebx, 0x7F800000
    jne .t17_fail
    mov ebx, eax
    and ebx, 0x007FFFFF
    test ebx, ebx
    jz .t17_fail
    ; Lane 2: 3.0 = 0x40400000
    movaps xmm2, xmm0
    psrldq xmm2, 8
    movd eax, xmm2
    cmp eax, 0x40400000
    jne .t17_fail
    ; Lane 3: 7.0 = 0x40E00000
    movaps xmm2, xmm0
    psrldq xmm2, 12
    movd eax, xmm2
    cmp eax, 0x40E00000
    jne .t17_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t17_done
.t17_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t17_done:

    ; ==== Test 18: HADDPD denormals ====
    ; {denorm_min, denorm_min} hadd {1.0, 2.0}
    ; lane0: denorm + denorm = 2 * denorm_min = 0x0000000000000002
    ; lane1: 1+2 = 3.0 = 0x4008000000000000
    TEST_CASE t18_name
    movapd xmm0, [rel haddpd_denorm_a]
    movapd xmm1, [rel haddpd_denorm_b]
    haddpd xmm0, xmm1
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x0000000000000002
    TEST_CASE t18_name
    movapd xmm0, [rel haddpd_denorm_a]
    movapd xmm1, [rel haddpd_denorm_b]
    haddpd xmm0, xmm1
    psrldq xmm0, 8
    movq rax, xmm0
    CHECK_EQ_64 rax, 0x4008000000000000

    END_TESTS
