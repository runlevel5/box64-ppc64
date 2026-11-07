; test_adcx_adox.asm - Test ADCX and ADOX multi-precision arithmetic
; Covers: ADCX (66 0F 38 F6) - add with CF, only modifies CF
;         ADOX (F3 0F 38 F6) - add with OF, only modifies OF
; These instructions enable two independent carry chains for multi-precision add.
%include "test_framework.inc"

section .data
    t1_name:  db "adcx basic no carry", 0
    t2_name:  db "adcx with carry in", 0
    t3_name:  db "adcx carry out", 0
    t4_name:  db "adcx preserves OF", 0
    t5_name:  db "adox basic no overflow", 0
    t6_name:  db "adox with overflow in", 0
    t7_name:  db "adox overflow out", 0
    t8_name:  db "adox preserves CF", 0
    t9_name:  db "adcx 64-bit carry chain", 0
    t10_name: db "adox 64-bit carry chain", 0
    t11_name: db "adcx+adox parallel chains", 0
    t12_name: db "adcx 64-bit overflow", 0

section .text
global _start

_start:
    INIT_TESTS

    ; ==== Test 1: ADCX basic, no carry in ====
    ; clc; adcx eax, ebx: eax = eax + ebx + 0
    TEST_CASE t1_name
    clc
    mov eax, 100
    mov ebx, 200
    adcx eax, ebx
    CHECK_EQ_32 eax, 300

    ; ==== Test 2: ADCX with carry in ====
    ; stc; adcx eax, ebx: eax = eax + ebx + 1
    TEST_CASE t2_name
    stc
    mov eax, 100
    mov ebx, 200
    adcx eax, ebx
    CHECK_EQ_32 eax, 301

    ; ==== Test 3: ADCX carry out ====
    ; 0xFFFFFFFF + 1 + 0 = 0, CF=1
    TEST_CASE t3_name
    clc
    mov eax, 0xFFFFFFFF
    mov ebx, 1
    adcx eax, ebx
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; ==== Test 4: ADCX preserves OF ====
    ; Set OF via 0x7FFFFFFF + 1 (sub-computation), then do adcx
    ; ADCX should NOT modify OF
    TEST_CASE t4_name
    ; First set OF=1: add 0x7FFFFFFF + 1 -> OF=1
    mov eax, 0x7FFFFFFF
    add eax, 1              ; OF=1, CF=0
    ; Now do adcx with CF=0 (from the add above, 0x80000000 didn't carry)
    mov eax, 10
    mov ebx, 20
    adcx eax, ebx           ; eax = 30, CF=0, OF should still be 1
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; ==== Test 5: ADOX basic, no overflow in ====
    ; Clear OF, adox eax, ebx: eax = eax + ebx + 0
    TEST_CASE t5_name
    ; Clear OF: xor eax,eax sets OF=0
    xor eax, eax            ; OF=0
    mov eax, 100
    mov ebx, 200
    adox eax, ebx
    CHECK_EQ_32 eax, 300

    ; ==== Test 6: ADOX with overflow in ====
    ; Set OF=1 first, then adox
    TEST_CASE t6_name
    mov eax, 0x7FFFFFFF
    add eax, 1              ; OF=1
    mov eax, 100
    mov ebx, 200
    adox eax, ebx           ; eax = 100 + 200 + 1(OF) = 301
    CHECK_EQ_32 eax, 301

    ; ==== Test 7: ADOX overflow out ====
    ; 0xFFFFFFFF + 1 + 0(OF) = 0, OF should be set
    TEST_CASE t7_name
    xor eax, eax            ; clear OF
    mov eax, 0xFFFFFFFF
    mov ebx, 1
    adox eax, ebx           ; wraps, OF=1 (carry out of ADOX sets OF)
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; ==== Test 8: ADOX preserves CF ====
    ; Set CF=1, then do adox — CF should remain 1
    TEST_CASE t8_name
    stc                      ; CF=1
    ; Clear OF for adox: we need OF=0 without clearing CF
    ; Use: pushf, clear OF in flags word, popf? No, simpler:
    ; lahf/sahf won't work for OF. Use pushf/popf:
    pushfq
    pop rax
    and rax, ~0x800          ; clear OF
    or rax, 0x0001           ; ensure CF=1
    push rax
    popfq                    ; CF=1, OF=0
    mov eax, 10
    mov ebx, 20
    adox eax, ebx            ; eax = 30, OF=0, CF should still be 1
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; ==== Test 9: ADCX 64-bit carry chain ====
    ; Add two 128-bit numbers using two adcx instructions
    ; A = 0x00000001_FFFFFFFF (low=0xFFFFFFFF, high=1)
    ; B = 0x00000001_00000001 (low=0x00000001, high=1)
    ; Sum = 0x00000003_00000000
    TEST_CASE t9_name
    clc
    mov eax, 0xFFFFFFFF
    mov ebx, 0x00000001
    adcx eax, ebx           ; eax = 0, CF=1
    mov ecx, 1
    mov edx, 1
    adcx ecx, edx           ; ecx = 1 + 1 + 1(CF) = 3
    CHECK_EQ_32 ecx, 3

    ; ==== Test 10: ADOX 64-bit carry chain ====
    ; Same but using overflow chain
    TEST_CASE t10_name
    ; Clear OF
    xor eax, eax
    mov eax, 0xFFFFFFFF
    mov ebx, 0x00000001
    adox eax, ebx           ; eax = 0, OF=1
    mov ecx, 1
    mov edx, 1
    adox ecx, edx           ; ecx = 1 + 1 + 1(OF) = 3
    CHECK_EQ_32 ecx, 3

    ; ==== Test 11: ADCX + ADOX parallel carry chains ====
    ; Use ADCX for chain 1 (CF) and ADOX for chain 2 (OF) simultaneously
    ; Chain1: 0xFFFFFFFF + 1 (via adcx) -> CF=1, then 0 + 0 + CF=1 -> 1
    ; Chain2: 0xFFFFFFFF + 1 (via adox) -> OF=1, then 0 + 0 + OF=1 -> 1
    TEST_CASE t11_name
    ; Clear both flags
    xor eax, eax             ; CF=0, OF=0
    ; Chain1 step1: adcx
    mov eax, 0xFFFFFFFF
    mov ebx, 1
    adcx eax, ebx            ; eax=0, CF=1, OF unchanged (=0)
    ; Chain2 step1: adox
    mov ecx, 0xFFFFFFFF
    mov edx, 1
    adox ecx, edx            ; ecx=0, OF=1, CF unchanged (=1)
    ; Chain1 step2: adcx (uses CF=1)
    mov eax, 0
    mov ebx, 0
    adcx eax, ebx            ; eax = 0 + 0 + 1 = 1
    ; Chain2 step2: adox (uses OF=1)
    mov ecx, 0
    mov edx, 0
    adox ecx, edx            ; ecx = 0 + 0 + 1 = 1
    ; Verify chain1 result
    cmp eax, 1
    jne .t11_fail
    cmp ecx, 1
    jne .t11_fail
    mov eax, 1
    CHECK_EQ_32 eax, 1
    jmp .t11_done
.t11_fail:
    mov eax, 0
    CHECK_EQ_32 eax, 1
.t11_done:

    ; ==== Test 12: ADCX 64-bit (REX.W) ====
    ; rax = 0xFFFFFFFFFFFFFFFF + 1 = 0, CF=1
    ; Note: ADCX only modifies CF, not ZF/SF/OF/PF
    TEST_CASE t12_name
    clc
    mov rax, 0xFFFFFFFFFFFFFFFF
    mov rbx, 1
    adcx rax, rbx
    SAVE_FLAGS
    ; Result should be 0 with CF=1 (ZF is NOT set by ADCX)
    CHECK_FLAGS_EQ CF, CF

    END_TESTS
