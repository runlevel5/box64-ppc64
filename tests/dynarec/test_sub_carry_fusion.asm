; test_sub_carry_fusion.asm - Tests for SUB -> carry flag fusion across block boundaries
; Covers: sub8/16/32/64 setting CF, consumed by ADC/SBB after a block boundary
;
; The key scenario: SUB produces a borrow (CF=1) or no borrow (CF=0),
; then a block boundary (call flag_barrier_ret) forces deferred flag
; materialization, then ADC/SBB consumes the carry flag.
;
; This exercises the nat_flags carry fusion path in the dynarec where
; emit_sub must preserve original operands (not just the result) so that
; the carry flag can be reconstructed at the consumer.
;
; Also tests sub32c (SUB with immediate constant) paths including small
; constants that may use ADDI optimization internally.
%include "test_framework.inc"

section .data
    ;; --- sub8 -> adc (CF=1) ---
    t_sub8_adc_cf1:     db "sub8->adc CF=1 borrow", 0
    t_sub8_adc_cf1_r:   db "sub8->adc CF=1 result", 0
    ;; --- sub8 -> adc (CF=0) ---
    t_sub8_adc_cf0:     db "sub8->adc CF=0 no borrow", 0
    t_sub8_adc_cf0_r:   db "sub8->adc CF=0 result", 0
    ;; --- sub8 -> sbb (CF=1) ---
    t_sub8_sbb_cf1:     db "sub8->sbb CF=1 borrow", 0
    t_sub8_sbb_cf1_r:   db "sub8->sbb CF=1 result", 0
    ;; --- sub8 -> sbb (CF=0) ---
    t_sub8_sbb_cf0:     db "sub8->sbb CF=0 no borrow", 0

    ;; --- sub16 -> adc (CF=1) ---
    t_sub16_adc_cf1:    db "sub16->adc CF=1 borrow", 0
    t_sub16_adc_cf1_r:  db "sub16->adc CF=1 result", 0
    ;; --- sub16 -> adc (CF=0) ---
    t_sub16_adc_cf0:    db "sub16->adc CF=0 no borrow", 0
    t_sub16_adc_cf0_r:  db "sub16->adc CF=0 result", 0
    ;; --- sub16 -> sbb (CF=1) ---
    t_sub16_sbb_cf1:    db "sub16->sbb CF=1 borrow", 0
    t_sub16_sbb_cf1_r:  db "sub16->sbb CF=1 result", 0

    ;; --- sub32 -> adc (CF=1) ---
    t_sub32_adc_cf1:    db "sub32->adc CF=1 borrow", 0
    t_sub32_adc_cf1_r:  db "sub32->adc CF=1 result", 0
    ;; --- sub32 -> adc (CF=0) ---
    t_sub32_adc_cf0:    db "sub32->adc CF=0 no borrow", 0
    t_sub32_adc_cf0_r:  db "sub32->adc CF=0 result", 0
    ;; --- sub32 -> sbb (CF=1) ---
    t_sub32_sbb_cf1:    db "sub32->sbb CF=1 borrow", 0
    t_sub32_sbb_cf1_r:  db "sub32->sbb CF=1 result", 0
    ;; --- sub32 -> sbb (CF=0) ---
    t_sub32_sbb_cf0:    db "sub32->sbb CF=0 no borrow", 0

    ;; --- sub64 -> adc (CF=1) ---
    t_sub64_adc_cf1:    db "sub64->adc CF=1 borrow", 0
    t_sub64_adc_cf1_r:  db "sub64->adc CF=1 result", 0
    ;; --- sub64 -> adc (CF=0) ---
    t_sub64_adc_cf0:    db "sub64->adc CF=0 no borrow", 0
    t_sub64_adc_cf0_r:  db "sub64->adc CF=0 result", 0
    ;; --- sub64 -> sbb (CF=1) ---
    t_sub64_sbb_cf1:    db "sub64->sbb CF=1 borrow", 0
    t_sub64_sbb_cf1_r:  db "sub64->sbb CF=1 result", 0
    ;; --- sub64 -> sbb (CF=0) ---
    t_sub64_sbb_cf0:    db "sub64->sbb CF=0 no borrow", 0

    ;; --- sub32 immediate (small constant, ADDI path) ---
    t_sub32c_sm_cf1:    db "sub32c small imm CF=1", 0
    t_sub32c_sm_cf1_r:  db "sub32c small imm CF=1 result", 0
    t_sub32c_sm_cf0:    db "sub32c small imm CF=0", 0
    t_sub32c_sm_cf0_r:  db "sub32c small imm CF=0 result", 0

    ;; --- sub32 immediate (large constant) ---
    t_sub32c_lg_cf1:    db "sub32c large imm CF=1", 0
    t_sub32c_lg_cf1_r:  db "sub32c large imm CF=1 result", 0

    ;; --- sub64 immediate ---
    t_sub64c_cf1:       db "sub64c imm CF=1 borrow", 0
    t_sub64c_cf1_r:     db "sub64c imm CF=1 result", 0

    ;; --- chained sub -> sub -> adc (double carry) ---
    t_chain_sub_adc:    db "sub32 chain->adc last CF", 0
    t_chain_sub_adc_r:  db "sub32 chain->adc result", 0

    ;; --- sub -> ZF (zero flag through fusion) ---
    t_sub32_zf:         db "sub32->jz CF=0 ZF=1", 0
    t_sub32_zf_r:       db "sub32->jz ZF result", 0

    ;; --- sub -> CF+ZF both set ---
    t_sub8_cfzf:        db "sub8 CF=1 ZF=0 via barrier", 0

section .text
global _start

flag_barrier_ret:
    ret

_start:
    INIT_TESTS

    ;; ================================================================
    ;; SUB8 -> ADC/SBB carry fusion
    ;; ================================================================

    ; sub8 borrow: 0x00 - 0x01 = 0xFF, CF=1
    ; then adc bl, 0 should add CF=1: 0x10 + 0 + 1 = 0x11
    TEST_CASE t_sub8_adc_cf1
    mov al, 0x00
    sub al, 0x01            ; CF=1 (borrow)
    call flag_barrier_ret   ; block boundary - deferred flags
    mov bl, 0x10
    adc bl, 0               ; bl = 0x10 + 0 + CF(1) = 0x11
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0    ; no carry out from adc

    TEST_CASE t_sub8_adc_cf1_r
    CHECK_EQ_32 ebx, 0x11

    ; sub8 no borrow: 0x05 - 0x03 = 0x02, CF=0
    ; then adc bl, 0 should add CF=0: 0x10 + 0 + 0 = 0x10
    TEST_CASE t_sub8_adc_cf0
    mov al, 0x05
    sub al, 0x03            ; CF=0
    call flag_barrier_ret
    mov bl, 0x10
    adc bl, 0               ; bl = 0x10 + 0 + CF(0) = 0x10
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub8_adc_cf0_r
    CHECK_EQ_32 ebx, 0x10

    ; sub8 borrow -> sbb: 0x00 - 0x01 = 0xFF, CF=1
    ; sbb bl, 0: 0x10 - 0 - CF(1) = 0x0F
    TEST_CASE t_sub8_sbb_cf1
    mov al, 0x00
    sub al, 0x01            ; CF=1
    call flag_barrier_ret
    mov bl, 0x10
    sbb bl, 0               ; bl = 0x10 - 0 - 1 = 0x0F
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub8_sbb_cf1_r
    CHECK_EQ_32 ebx, 0x0F

    ; sub8 no borrow -> sbb: 0x05 - 0x03 = 0x02, CF=0
    ; sbb bl, 0: 0x10 - 0 - 0 = 0x10
    TEST_CASE t_sub8_sbb_cf0
    mov al, 0x05
    sub al, 0x03            ; CF=0
    call flag_barrier_ret
    mov bl, 0x10
    sbb bl, 0
    CHECK_EQ_32 ebx, 0x10

    ;; ================================================================
    ;; SUB16 -> ADC/SBB carry fusion
    ;; ================================================================

    ; sub16 borrow: 0x0000 - 0x0001 = 0xFFFF, CF=1
    ; adc bx, 0: 0x1000 + 0 + 1 = 0x1001
    TEST_CASE t_sub16_adc_cf1
    mov ax, 0x0000
    sub ax, 0x0001          ; CF=1
    call flag_barrier_ret
    mov bx, 0x1000
    adc bx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub16_adc_cf1_r
    CHECK_EQ_32 ebx, 0x1001

    ; sub16 no borrow: 0x1234 - 0x0034 = 0x1200, CF=0
    ; adc bx, 0: 0x1000 + 0 + 0 = 0x1000
    TEST_CASE t_sub16_adc_cf0
    mov ax, 0x1234
    sub ax, 0x0034          ; CF=0
    call flag_barrier_ret
    mov bx, 0x1000
    adc bx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub16_adc_cf0_r
    CHECK_EQ_32 ebx, 0x1000

    ; sub16 borrow -> sbb: 0x0000 - 0x0001 = 0xFFFF, CF=1
    ; sbb bx, 0: 0x1000 - 0 - 1 = 0x0FFF
    TEST_CASE t_sub16_sbb_cf1
    mov ax, 0x0000
    sub ax, 0x0001          ; CF=1
    call flag_barrier_ret
    mov bx, 0x1000
    sbb bx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub16_sbb_cf1_r
    CHECK_EQ_32 ebx, 0x0FFF

    ;; ================================================================
    ;; SUB32 -> ADC/SBB carry fusion
    ;; ================================================================

    ; sub32 borrow: 0x00000000 - 0x00000001 = 0xFFFFFFFF, CF=1
    ; adc ebx, 0: 0x10000000 + 0 + 1 = 0x10000001
    TEST_CASE t_sub32_adc_cf1
    mov eax, 0x00000000
    sub eax, 0x00000001     ; CF=1
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub32_adc_cf1_r
    CHECK_EQ_32 ebx, 0x10000001

    ; sub32 no borrow: 0x12345678 - 0x00000078 = 0x12345600, CF=0
    ; adc ebx, 0: 0x10000000 + 0 + 0 = 0x10000000
    TEST_CASE t_sub32_adc_cf0
    mov eax, 0x12345678
    sub eax, 0x00000078     ; CF=0
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub32_adc_cf0_r
    CHECK_EQ_32 ebx, 0x10000000

    ; sub32 borrow -> sbb: 0 - 1 = 0xFFFFFFFF, CF=1
    ; sbb ebx, 0: 0x10000000 - 0 - 1 = 0x0FFFFFFF
    TEST_CASE t_sub32_sbb_cf1
    mov eax, 0
    sub eax, 1              ; CF=1
    call flag_barrier_ret
    mov ebx, 0x10000000
    sbb ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub32_sbb_cf1_r
    CHECK_EQ_32 ebx, 0x0FFFFFFF

    ; sub32 no borrow -> sbb: 5 - 3 = 2, CF=0
    ; sbb ebx, 0: 0x10000000 - 0 - 0 = 0x10000000
    TEST_CASE t_sub32_sbb_cf0
    mov eax, 5
    sub eax, 3              ; CF=0
    call flag_barrier_ret
    mov ebx, 0x10000000
    sbb ebx, 0
    CHECK_EQ_32 ebx, 0x10000000

    ;; ================================================================
    ;; SUB64 -> ADC/SBB carry fusion
    ;; ================================================================

    ; sub64 borrow: 0 - 1 = 0xFFFFFFFFFFFFFFFF, CF=1
    ; adc rbx, 0: 0x100000000 + 0 + 1 = 0x100000001
    TEST_CASE t_sub64_adc_cf1
    xor rax, rax
    sub rax, 1              ; CF=1
    call flag_barrier_ret
    mov rbx, 0x100000000
    adc rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub64_adc_cf1_r
    CHECK_EQ_64 rbx, 0x100000001

    ; sub64 no borrow: 0x1000 - 0x0100 = 0x0F00, CF=0
    ; adc rbx, 0: 0x100000000 + 0 + 0 = 0x100000000
    TEST_CASE t_sub64_adc_cf0
    mov rax, 0x1000
    sub rax, 0x0100         ; CF=0
    call flag_barrier_ret
    mov rbx, 0x100000000
    adc rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub64_adc_cf0_r
    CHECK_EQ_64 rbx, 0x100000000

    ; sub64 borrow -> sbb: 0 - 1, CF=1
    ; sbb rbx, 0: 0x100000000 - 0 - 1 = 0x0FFFFFFFF
    TEST_CASE t_sub64_sbb_cf1
    xor rax, rax
    sub rax, 1              ; CF=1
    call flag_barrier_ret
    mov rbx, 0x100000000
    sbb rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub64_sbb_cf1_r
    CHECK_EQ_64 rbx, 0x0FFFFFFFF

    ; sub64 no borrow -> sbb: 0x1000 - 0x0100, CF=0
    ; sbb rbx, 0: 0x100000000 - 0 - 0 = 0x100000000
    TEST_CASE t_sub64_sbb_cf0
    mov rax, 0x1000
    sub rax, 0x0100         ; CF=0
    call flag_barrier_ret
    mov rbx, 0x100000000
    sbb rbx, 0
    CHECK_EQ_64 rbx, 0x100000000

    ;; ================================================================
    ;; SUB32 with immediate constant (sub32c path)
    ;; ================================================================

    ; sub32c small immediate (fits in ADDI path): 0 - 5 = borrow, CF=1
    ; adc ebx, 0: 0x10000000 + 0 + 1 = 0x10000001
    TEST_CASE t_sub32c_sm_cf1
    mov eax, 0
    sub eax, 5              ; small constant, CF=1
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub32c_sm_cf1_r
    CHECK_EQ_32 ebx, 0x10000001

    ; sub32c small immediate no borrow: 100 - 5 = 95, CF=0
    ; adc ebx, 0: 0x10000000 + 0 + 0 = 0x10000000
    TEST_CASE t_sub32c_sm_cf0
    mov eax, 100
    sub eax, 5              ; CF=0
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub32c_sm_cf0_r
    CHECK_EQ_32 ebx, 0x10000000

    ; sub32c large immediate: 0x00001000 - 0x00002000 = borrow, CF=1
    ; adc ebx, 0: 0x10000000 + 0 + 1 = 0x10000001
    TEST_CASE t_sub32c_lg_cf1
    mov eax, 0x00001000
    sub eax, 0x00002000     ; large constant, CF=1
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub32c_lg_cf1_r
    CHECK_EQ_32 ebx, 0x10000001

    ;; ================================================================
    ;; SUB64 with immediate constant
    ;; ================================================================

    ; sub64 imm: 0 - 1 = borrow, CF=1
    ; adc rbx, 0: 0x100000000 + 0 + 1 = 0x100000001
    TEST_CASE t_sub64c_cf1
    xor rax, rax
    sub rax, 1              ; CF=1
    call flag_barrier_ret
    mov rbx, 0x100000000
    adc rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_sub64c_cf1_r
    CHECK_EQ_64 rbx, 0x100000001

    ;; ================================================================
    ;; Chained SUB -> block boundary -> ADC
    ;; Tests that only the LAST sub's CF is visible
    ;; ================================================================

    ; First sub: 5 - 3 = 2, CF=0
    ; Second sub: 0 - 1 = 0xFFFFFFFF, CF=1
    ; After barrier, CF should be 1 (from second sub)
    TEST_CASE t_chain_sub_adc
    mov eax, 5
    sub eax, 3              ; CF=0
    mov ecx, 0
    sub ecx, 1              ; CF=1 (this is the one that matters)
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0              ; ebx = 0x10000000 + 0 + 1 = 0x10000001
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_chain_sub_adc_r
    CHECK_EQ_32 ebx, 0x10000001

    ;; ================================================================
    ;; SUB -> ZF through fusion (not carry, but verify no regression)
    ;; ================================================================

    ; sub32: 0x42 - 0x42 = 0, ZF=1, CF=0
    ; After barrier, check both ZF and CF
    TEST_CASE t_sub32_zf
    mov eax, 0x42
    sub eax, 0x42           ; ZF=1, CF=0
    call flag_barrier_ret
    mov ebx, eax            ; save result before framework clobbers eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF), ZF

    TEST_CASE t_sub32_zf_r
    CHECK_EQ_32 ebx, 0x00000000

    ;; ================================================================
    ;; SUB8 -> CF=1, ZF=0 (verify both flags correct after barrier)
    ;; ================================================================

    ; sub8: 0x00 - 0x01 = 0xFF, CF=1, ZF=0, SF=1
    TEST_CASE t_sub8_cfzf
    mov al, 0x00
    sub al, 0x01            ; CF=1, ZF=0, SF=1
    call flag_barrier_ret
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF|SF), (CF|SF)

    ;; ================================================================
    END_TESTS
