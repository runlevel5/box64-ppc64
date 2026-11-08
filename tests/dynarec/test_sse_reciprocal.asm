; test_sse_reciprocal.asm - Test SSE reciprocal/reciprocal-sqrt instructions
; Covers: RSQRTPS (0F 52), RCPPS (0F 53), RSQRTSS (F3 0F 52), RCPSS (F3 0F 53)
; These are approximate instructions (12-bit precision), so we test within tolerance.
%include "test_framework.inc"

section .data
    align 16
    ; RCPPS: approximate 1/x for each float
    rcpps_in:   dd 1.0, 2.0, 4.0, 0.5
    ; Expected: ~1.0, ~0.5, ~0.25, ~2.0  (within 1.5/4096 relative error)

    ; RSQRTPS: approximate 1/sqrt(x)
    rsqrtps_in: dd 1.0, 4.0, 16.0, 0.25
    ; Expected: ~1.0, ~0.5, ~0.25, ~2.0

    ; RCPSS: scalar reciprocal
    rcpss_in:   dd 8.0, 0.0, 0.0, 0.0
    ; Expected: ~0.125

    ; RSQRTSS: scalar reciprocal sqrt
    rsqrtss_in: dd 64.0, 0.0, 0.0, 0.0
    ; Expected: ~0.125

    ; Tolerance: relative error < 1.5 * 2^-12 ~= 0.000366
    ; We'll check with absolute tolerance since values are near known results
    ; For result ~R, check |got - R| < R * 0.001 (generous)
    ; Simpler: multiply result by input and check near 1.0 for RCP
    ; or multiply result^2 by input and check near 1.0 for RSQRT

    ; Values for checking rcp: rcp(x) * x should be ~1.0
    one_ps:     dd 1.0, 1.0, 1.0, 1.0
    ; Tolerance bounds: 0.999 and 1.001 for rcp*x product
    lo_bound:   dd 0.999, 0.999, 0.999, 0.999
    hi_bound:   dd 1.001, 1.001, 1.001, 1.001
    lo_bound_d: dq 0.999, 0.999
    hi_bound_d: dq 1.001, 1.001

    ; Additional test: large value
    rcpps_large: dd 1000.0, 0.001, 100.0, 0.01
    rsqrtps_large: dd 100.0, 10000.0, 0.01, 1.0

    t1_name:  db "rcpps basic (rcp*x~=1)", 0
    t2_name:  db "rsqrtps basic (rsq^2*x~=1)", 0
    t3_name:  db "rcpss scalar (rcp*x~=1)", 0
    t4_name:  db "rsqrtss scalar (rsq^2*x~=1)", 0
    t5_name:  db "rcpps large values", 0
    t6_name:  db "rsqrtps large values", 0
    t7_name:  db "rcpps preserves upper on rcpss", 0
    t8_name:  db "rsqrtps ones input", 0

    rsqrt_ones_in: dd 1.0, 1.0, 1.0, 1.0

section .bss
    alignb 16
    result: resb 16

section .text
global _start

; Helper: check all 4 floats in xmm0 are between lo_bound and hi_bound
; Sets eax=1 if pass, eax=0 if fail
; Clobbers xmm2, xmm3
check_bounds_ps:
    ; xmm0 = values to check
    movaps xmm2, [rel lo_bound]
    movaps xmm3, [rel hi_bound]
    ; Check val >= lo: cmpps xmm2, xmm0, 2 (LE) -> all should be true
    cmpleps xmm2, xmm0          ; xmm2 = (lo <= val) ? 0xFFFFFFFF : 0
    ; Check val <= hi: cmpps xmm0_copy, xmm3, 2 (LE)
    cmpleps xmm0, xmm3          ; xmm0 = (val <= hi) ? 0xFFFFFFFF : 0
    ; AND them
    andps xmm0, xmm2
    ; All bits should be set if all passed
    movmskps eax, xmm0
    cmp eax, 0xF
    je .cb_pass
    xor eax, eax
    ret
.cb_pass:
    mov eax, 1
    ret

_start:
    INIT_TESTS

    ; ==== Test 1: RCPPS basic ====
    ; rcp(x) * x should be ~1.0 for all 4 elements
    TEST_CASE t1_name
    movaps xmm0, [rel rcpps_in]
    rcpps xmm1, xmm0             ; xmm1 = ~1/x
    mulps xmm1, xmm0             ; xmm1 = ~1/x * x ~= 1.0
    movaps xmm0, xmm1
    call check_bounds_ps
    CHECK_EQ_32 eax, 1

    ; ==== Test 2: RSQRTPS basic ====
    ; rsqrt(x)^2 * x should be ~1.0
    TEST_CASE t2_name
    movaps xmm0, [rel rsqrtps_in]
    rsqrtps xmm1, xmm0           ; xmm1 = ~1/sqrt(x)
    movaps xmm2, xmm1
    mulps xmm1, xmm2             ; xmm1 = ~1/x
    mulps xmm1, xmm0             ; xmm1 = ~1/x * x ~= 1.0
    movaps xmm0, xmm1
    call check_bounds_ps
    CHECK_EQ_32 eax, 1

    ; ==== Test 3: RCPSS scalar ====
    ; Only operates on element 0; rcp(8) ~= 0.125, so 0.125 * 8 ~= 1.0
    TEST_CASE t3_name
    movaps xmm0, [rel rcpss_in]
    rcpss xmm1, xmm0             ; xmm1[0] = ~1/8
    mulss xmm1, xmm0             ; xmm1[0] = ~1/8 * 8 ~= 1.0
    ; Check element 0 is between 0.999 and 1.001
    movss xmm2, [rel lo_bound]
    comiss xmm1, xmm2            ; xmm1 >= 0.999?
    jb .t3_fail
    movss xmm2, [rel hi_bound]
    comiss xmm2, xmm1            ; 1.001 >= xmm1?
    jb .t3_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t3_done
.t3_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t3_done:

    ; ==== Test 4: RSQRTSS scalar ====
    ; rsqrt(64) ~= 0.125, so 0.125^2 * 64 = 0.015625 * 64 = 1.0
    TEST_CASE t4_name
    movaps xmm0, [rel rsqrtss_in]
    rsqrtss xmm1, xmm0
    movaps xmm2, xmm1
    mulss xmm1, xmm2             ; xmm1[0] = rsqrt^2
    mulss xmm1, xmm0             ; xmm1[0] ~= 1.0
    movss xmm2, [rel lo_bound]
    comiss xmm1, xmm2
    jb .t4_fail
    movss xmm2, [rel hi_bound]
    comiss xmm2, xmm1
    jb .t4_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t4_done
.t4_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t4_done:

    ; ==== Test 5: RCPPS large values ====
    TEST_CASE t5_name
    movaps xmm0, [rel rcpps_large]
    rcpps xmm1, xmm0
    mulps xmm1, xmm0
    movaps xmm0, xmm1
    call check_bounds_ps
    CHECK_EQ_32 eax, 1

    ; ==== Test 6: RSQRTPS large values ====
    TEST_CASE t6_name
    movaps xmm0, [rel rsqrtps_large]
    rsqrtps xmm1, xmm0
    movaps xmm2, xmm1
    mulps xmm1, xmm2
    mulps xmm1, xmm0
    movaps xmm0, xmm1
    call check_bounds_ps
    CHECK_EQ_32 eax, 1

    ; ==== Test 7: RCPSS preserves upper elements ====
    ; Load [1, 2, 3, 4], do rcpss from [8, ...], check elements 1-3 unchanged
    TEST_CASE t7_name
    movaps xmm0, [rel rcpps_in]     ; [1.0, 2.0, 4.0, 0.5]
    movaps xmm1, xmm0               ; save copy
    movaps xmm2, [rel rcpss_in]     ; [8.0, ...]
    rcpss xmm0, xmm2                ; xmm0[0] = ~1/8, upper unchanged
    ; Check upper 3 elements unchanged by comparing bytes 4-15
    psrldq xmm0, 4                  ; shift out element 0
    psrldq xmm1, 4
    movq rax, xmm0
    movq rbx, xmm1
    cmp rax, rbx
    jne .t7_fail
    psrldq xmm0, 8
    psrldq xmm1, 8
    movd eax, xmm0
    movd ebx, xmm1
    cmp eax, ebx
    jne .t7_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t7_done
.t7_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t7_done:

    ; ==== Test 8: RSQRTPS all ones ====
    ; rsqrt(1.0) should be ~1.0 for all elements
    TEST_CASE t8_name
    movaps xmm0, [rel rsqrt_ones_in]
    rsqrtps xmm1, xmm0
    ; Each element should be ~1.0; multiply by input (=1.0) to verify
    mulps xmm1, xmm0
    movaps xmm0, xmm1
    call check_bounds_ps
    CHECK_EQ_32 eax, 1

    END_TESTS
