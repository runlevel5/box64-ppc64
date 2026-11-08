; test_add_carry_fusion.asm - Tests for ADD -> carry flag fusion across block boundaries
; Covers: add8/16/32/64 setting CF, consumed by ADC/SBB after a block boundary
;
; The key scenario: ADD produces a carry (CF=1) or no carry (CF=0),
; then a block boundary (call flag_barrier_ret) forces deferred flag
; materialization, then ADC/SBB consumes the carry flag.
;
; This exercises the nat_flags carry fusion path in the dynarec where
; emit_add must preserve the original first operand (not just the result)
; so that the carry flag can be reconstructed at the consumer via
; CF = (result < saved_op1) unsigned.
;
; Also tests add32c (ADD with immediate constant) paths including small
; constants that may use ADDI optimization internally.
%include "test_framework.inc"

section .data
    ;; --- add8 -> adc (CF=1) ---
    t_add8_adc_cf1:     db "add8->adc CF=1 carry", 0
    t_add8_adc_cf1_r:   db "add8->adc CF=1 result", 0
    ;; --- add8 -> adc (CF=0) ---
    t_add8_adc_cf0:     db "add8->adc CF=0 no carry", 0
    t_add8_adc_cf0_r:   db "add8->adc CF=0 result", 0
    ;; --- add8 -> sbb (CF=1) ---
    t_add8_sbb_cf1:     db "add8->sbb CF=1 carry", 0
    t_add8_sbb_cf1_r:   db "add8->sbb CF=1 result", 0
    ;; --- add8 -> sbb (CF=0) ---
    t_add8_sbb_cf0:     db "add8->sbb CF=0 no carry", 0

    ;; --- add16 -> adc (CF=1) ---
    t_add16_adc_cf1:    db "add16->adc CF=1 carry", 0
    t_add16_adc_cf1_r:  db "add16->adc CF=1 result", 0
    ;; --- add16 -> adc (CF=0) ---
    t_add16_adc_cf0:    db "add16->adc CF=0 no carry", 0
    t_add16_adc_cf0_r:  db "add16->adc CF=0 result", 0
    ;; --- add16 -> sbb (CF=1) ---
    t_add16_sbb_cf1:    db "add16->sbb CF=1 carry", 0
    t_add16_sbb_cf1_r:  db "add16->sbb CF=1 result", 0

    ;; --- add32 -> adc (CF=1) ---
    t_add32_adc_cf1:    db "add32->adc CF=1 carry", 0
    t_add32_adc_cf1_r:  db "add32->adc CF=1 result", 0
    ;; --- add32 -> adc (CF=0) ---
    t_add32_adc_cf0:    db "add32->adc CF=0 no carry", 0
    t_add32_adc_cf0_r:  db "add32->adc CF=0 result", 0
    ;; --- add32 -> sbb (CF=1) ---
    t_add32_sbb_cf1:    db "add32->sbb CF=1 carry", 0
    t_add32_sbb_cf1_r:  db "add32->sbb CF=1 result", 0
    ;; --- add32 -> sbb (CF=0) ---
    t_add32_sbb_cf0:    db "add32->sbb CF=0 no carry", 0

    ;; --- add64 -> adc (CF=1) ---
    t_add64_adc_cf1:    db "add64->adc CF=1 carry", 0
    t_add64_adc_cf1_r:  db "add64->adc CF=1 result", 0
    ;; --- add64 -> adc (CF=0) ---
    t_add64_adc_cf0:    db "add64->adc CF=0 no carry", 0
    t_add64_adc_cf0_r:  db "add64->adc CF=0 result", 0
    ;; --- add64 -> sbb (CF=1) ---
    t_add64_sbb_cf1:    db "add64->sbb CF=1 carry", 0
    t_add64_sbb_cf1_r:  db "add64->sbb CF=1 result", 0
    ;; --- add64 -> sbb (CF=0) ---
    t_add64_sbb_cf0:    db "add64->sbb CF=0 no carry", 0

    ;; --- add32 immediate (small constant, ADDI path) ---
    t_add32c_sm_cf1:    db "add32c small imm CF=1", 0
    t_add32c_sm_cf1_r:  db "add32c small imm CF=1 result", 0
    t_add32c_sm_cf0:    db "add32c small imm CF=0", 0
    t_add32c_sm_cf0_r:  db "add32c small imm CF=0 result", 0

    ;; --- add32 immediate (large constant) ---
    t_add32c_lg_cf1:    db "add32c large imm CF=1", 0
    t_add32c_lg_cf1_r:  db "add32c large imm CF=1 result", 0

    ;; --- add64 immediate ---
    t_add64c_cf1:       db "add64c imm CF=1 carry", 0
    t_add64c_cf1_r:     db "add64c imm CF=1 result", 0

    ;; --- chained add -> add -> adc (double carry) ---
    t_chain_add_adc:    db "add32 chain->adc last CF", 0
    t_chain_add_adc_r:  db "add32 chain->adc result", 0

    ;; --- add -> ZF (zero flag through fusion) ---
    t_add32_zf:         db "add32->jz CF=0 ZF=1", 0
    t_add32_zf_r:       db "add32->jz ZF result", 0

    ;; --- add -> CF+ZF both set (impossible for ADD, CF=1 means result < op1, so result != 0 unless op1==0 and op2==0 which gives CF=0) ---
    ;; Instead: add8 CF=1, ZF=0, SF=0 (verify all three)
    t_add8_cfzf:        db "add8 CF=1 ZF=0 via barrier", 0

    ;; --- add8c immediate path ---
    t_add8c_cf1:        db "add8c imm CF=1 carry", 0
    t_add8c_cf1_r:      db "add8c imm CF=1 result", 0
    t_add8c_cf0:        db "add8c imm CF=0 no carry", 0

    ;; --- add16 with register operand ---
    t_add16_reg_cf1:    db "add16 reg CF=1 carry", 0
    t_add16_reg_cf1_r:  db "add16 reg CF=1 result", 0

section .text
global _start

flag_barrier_ret:
    ret

_start:
    INIT_TESTS

    ;; ================================================================
    ;; ADD8 -> ADC/SBB carry fusion
    ;; ================================================================

    ; add8 carry: 0xFF + 0x01 = 0x00 (wraps), CF=1
    ; then adc bl, 0 should add CF=1: 0x10 + 0 + 1 = 0x11
    TEST_CASE t_add8_adc_cf1
    mov al, 0xFF
    add al, 0x01            ; CF=1 (carry out)
    call flag_barrier_ret   ; block boundary - deferred flags
    mov bl, 0x10
    adc bl, 0               ; bl = 0x10 + 0 + CF(1) = 0x11
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0    ; no carry out from adc

    TEST_CASE t_add8_adc_cf1_r
    CHECK_EQ_32 ebx, 0x11

    ; add8 no carry: 0x05 + 0x03 = 0x08, CF=0
    ; then adc bl, 0 should add CF=0: 0x10 + 0 + 0 = 0x10
    TEST_CASE t_add8_adc_cf0
    mov al, 0x05
    add al, 0x03            ; CF=0
    call flag_barrier_ret
    mov bl, 0x10
    adc bl, 0               ; bl = 0x10 + 0 + CF(0) = 0x10
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add8_adc_cf0_r
    CHECK_EQ_32 ebx, 0x10

    ; add8 carry -> sbb: 0xFF + 0x01 = 0x00, CF=1
    ; sbb bl, 0: 0x10 - 0 - CF(1) = 0x0F
    TEST_CASE t_add8_sbb_cf1
    mov al, 0xFF
    add al, 0x01            ; CF=1
    call flag_barrier_ret
    mov bl, 0x10
    sbb bl, 0               ; bl = 0x10 - 0 - 1 = 0x0F
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add8_sbb_cf1_r
    CHECK_EQ_32 ebx, 0x0F

    ; add8 no carry -> sbb: 0x05 + 0x03 = 0x08, CF=0
    ; sbb bl, 0: 0x10 - 0 - 0 = 0x10
    TEST_CASE t_add8_sbb_cf0
    mov al, 0x05
    add al, 0x03            ; CF=0
    call flag_barrier_ret
    mov bl, 0x10
    sbb bl, 0
    CHECK_EQ_32 ebx, 0x10

    ;; ================================================================
    ;; ADD16 -> ADC/SBB carry fusion
    ;; ================================================================

    ; add16 carry: 0xFFFF + 0x0001 = 0x0000 (wraps), CF=1
    ; adc bx, 0: 0x1000 + 0 + 1 = 0x1001
    TEST_CASE t_add16_adc_cf1
    mov ax, 0xFFFF
    add ax, 0x0001          ; CF=1
    call flag_barrier_ret
    mov bx, 0x1000
    adc bx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add16_adc_cf1_r
    CHECK_EQ_32 ebx, 0x1001

    ; add16 no carry: 0x1234 + 0x0034 = 0x1268, CF=0
    ; adc bx, 0: 0x1000 + 0 + 0 = 0x1000
    TEST_CASE t_add16_adc_cf0
    mov ax, 0x1234
    add ax, 0x0034          ; CF=0
    call flag_barrier_ret
    mov bx, 0x1000
    adc bx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add16_adc_cf0_r
    CHECK_EQ_32 ebx, 0x1000

    ; add16 carry -> sbb: 0xFFFF + 0x0001 = 0x0000, CF=1
    ; sbb bx, 0: 0x1000 - 0 - 1 = 0x0FFF
    TEST_CASE t_add16_sbb_cf1
    mov ax, 0xFFFF
    add ax, 0x0001          ; CF=1
    call flag_barrier_ret
    mov bx, 0x1000
    sbb bx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add16_sbb_cf1_r
    CHECK_EQ_32 ebx, 0x0FFF

    ;; ================================================================
    ;; ADD32 -> ADC/SBB carry fusion
    ;; ================================================================

    ; add32 carry: 0xFFFFFFFF + 0x00000001 = 0x00000000, CF=1
    ; adc ebx, 0: 0x10000000 + 0 + 1 = 0x10000001
    TEST_CASE t_add32_adc_cf1
    mov eax, 0xFFFFFFFF
    add eax, 0x00000001     ; CF=1
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add32_adc_cf1_r
    CHECK_EQ_32 ebx, 0x10000001

    ; add32 no carry: 0x12345678 + 0x00000078 = 0x123456F0, CF=0
    ; adc ebx, 0: 0x10000000 + 0 + 0 = 0x10000000
    TEST_CASE t_add32_adc_cf0
    mov eax, 0x12345678
    add eax, 0x00000078     ; CF=0
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add32_adc_cf0_r
    CHECK_EQ_32 ebx, 0x10000000

    ; add32 carry -> sbb: 0xFFFFFFFF + 1 = 0, CF=1
    ; sbb ebx, 0: 0x10000000 - 0 - 1 = 0x0FFFFFFF
    TEST_CASE t_add32_sbb_cf1
    mov eax, 0xFFFFFFFF
    add eax, 1              ; CF=1
    call flag_barrier_ret
    mov ebx, 0x10000000
    sbb ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add32_sbb_cf1_r
    CHECK_EQ_32 ebx, 0x0FFFFFFF

    ; add32 no carry -> sbb: 5 + 3 = 8, CF=0
    ; sbb ebx, 0: 0x10000000 - 0 - 0 = 0x10000000
    TEST_CASE t_add32_sbb_cf0
    mov eax, 5
    add eax, 3              ; CF=0
    call flag_barrier_ret
    mov ebx, 0x10000000
    sbb ebx, 0
    CHECK_EQ_32 ebx, 0x10000000

    ;; ================================================================
    ;; ADD64 -> ADC/SBB carry fusion
    ;; ================================================================

    ; add64 carry: 0xFFFFFFFFFFFFFFFF + 1 = 0, CF=1
    ; adc rbx, 0: 0x100000000 + 0 + 1 = 0x100000001
    TEST_CASE t_add64_adc_cf1
    mov rax, -1             ; 0xFFFFFFFFFFFFFFFF
    add rax, 1              ; CF=1
    call flag_barrier_ret
    mov rbx, 0x100000000
    adc rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add64_adc_cf1_r
    CHECK_EQ_64 rbx, 0x100000001

    ; add64 no carry: 0x1000 + 0x0100 = 0x1100, CF=0
    ; adc rbx, 0: 0x100000000 + 0 + 0 = 0x100000000
    TEST_CASE t_add64_adc_cf0
    mov rax, 0x1000
    add rax, 0x0100         ; CF=0
    call flag_barrier_ret
    mov rbx, 0x100000000
    adc rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add64_adc_cf0_r
    CHECK_EQ_64 rbx, 0x100000000

    ; add64 carry -> sbb: 0xFFFFFFFFFFFFFFFF + 1, CF=1
    ; sbb rbx, 0: 0x100000000 - 0 - 1 = 0x0FFFFFFFF
    TEST_CASE t_add64_sbb_cf1
    mov rax, -1
    add rax, 1              ; CF=1
    call flag_barrier_ret
    mov rbx, 0x100000000
    sbb rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add64_sbb_cf1_r
    CHECK_EQ_64 rbx, 0x0FFFFFFFF

    ; add64 no carry -> sbb: 0x1000 + 0x0100, CF=0
    ; sbb rbx, 0: 0x100000000 - 0 - 0 = 0x100000000
    TEST_CASE t_add64_sbb_cf0
    mov rax, 0x1000
    add rax, 0x0100         ; CF=0
    call flag_barrier_ret
    mov rbx, 0x100000000
    sbb rbx, 0
    CHECK_EQ_64 rbx, 0x100000000

    ;; ================================================================
    ;; ADD32 with immediate constant (add32c path)
    ;; ================================================================

    ; add32c small immediate (fits in ADDI path): 0xFFFFFFF0 + 5 = 0xFFFFFFF5, CF=0
    ; adc ebx, 0: 0x10000000 + 0 + 0 = 0x10000000
    TEST_CASE t_add32c_sm_cf0
    mov eax, 0xFFFFFFF0
    add eax, 5              ; small constant, CF=0 (no wrap)
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add32c_sm_cf0_r
    CHECK_EQ_32 ebx, 0x10000000

    ; add32c small immediate carry: 0xFFFFFFFF + 5 = 4, CF=1
    ; adc ebx, 0: 0x10000000 + 0 + 1 = 0x10000001
    TEST_CASE t_add32c_sm_cf1
    mov eax, 0xFFFFFFFF
    add eax, 5              ; small constant, CF=1 (wraps)
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add32c_sm_cf1_r
    CHECK_EQ_32 ebx, 0x10000001

    ; add32c large immediate: 0xFFFF0000 + 0x00020000 = 0x00010000, CF=1
    ; adc ebx, 0: 0x10000000 + 0 + 1 = 0x10000001
    TEST_CASE t_add32c_lg_cf1
    mov eax, 0xFFFF0000
    add eax, 0x00020000     ; large constant, CF=1
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add32c_lg_cf1_r
    CHECK_EQ_32 ebx, 0x10000001

    ;; ================================================================
    ;; ADD64 with immediate constant
    ;; ================================================================

    ; add64 imm: 0xFFFFFFFFFFFFFFFF + 1 = 0, CF=1
    ; adc rbx, 0: 0x100000000 + 0 + 1 = 0x100000001
    TEST_CASE t_add64c_cf1
    mov rax, -1
    add rax, 1              ; CF=1
    call flag_barrier_ret
    mov rbx, 0x100000000
    adc rbx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add64c_cf1_r
    CHECK_EQ_64 rbx, 0x100000001

    ;; ================================================================
    ;; Chained ADD -> block boundary -> ADC
    ;; Tests that only the LAST add's CF is visible
    ;; ================================================================

    ; First add: 0xFFFFFFFF + 1 = 0, CF=1
    ; Second add: 5 + 3 = 8, CF=0
    ; After barrier, CF should be 0 (from second add)
    TEST_CASE t_chain_add_adc
    mov eax, 0xFFFFFFFF
    add eax, 1              ; CF=1
    mov ecx, 5
    add ecx, 3              ; CF=0 (this is the one that matters)
    call flag_barrier_ret
    mov ebx, 0x10000000
    adc ebx, 0              ; ebx = 0x10000000 + 0 + 0 = 0x10000000
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_chain_add_adc_r
    CHECK_EQ_32 ebx, 0x10000000

    ;; ================================================================
    ;; ADD -> ZF through fusion (not carry, but verify no regression)
    ;; ================================================================

    ; add32: 0x00000000 + 0x00000000 = 0, ZF=1, CF=0
    ; After barrier, check both ZF and CF
    TEST_CASE t_add32_zf
    mov eax, 0x00000000
    add eax, 0x00000000     ; ZF=1, CF=0
    call flag_barrier_ret
    mov ebx, eax            ; save result before framework clobbers eax
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF), ZF

    TEST_CASE t_add32_zf_r
    CHECK_EQ_32 ebx, 0x00000000

    ;; ================================================================
    ;; ADD8 -> CF=1, ZF=0 (verify multiple flags correct after barrier)
    ;; For ADD: 0xFF + 0x02 = 0x01, CF=1, ZF=0, SF=0
    ;; ================================================================

    TEST_CASE t_add8_cfzf
    mov al, 0xFF
    add al, 0x02            ; CF=1, ZF=0, SF=0
    call flag_barrier_ret
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF|SF), CF

    ;; ================================================================
    ;; ADD8 with immediate constant (add8c path)
    ;; ================================================================

    ; add8c carry: 0xFF + 5 = 0x04, CF=1
    ; adc bl, 0: 0x10 + 0 + 1 = 0x11
    TEST_CASE t_add8c_cf1
    mov al, 0xFF
    add al, 5               ; CF=1
    call flag_barrier_ret
    mov bl, 0x10
    adc bl, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add8c_cf1_r
    CHECK_EQ_32 ebx, 0x11

    ; add8c no carry: 0x05 + 3 = 0x08, CF=0
    TEST_CASE t_add8c_cf0
    mov al, 0x05
    add al, 3               ; CF=0
    call flag_barrier_ret
    mov bl, 0x10
    adc bl, 0
    CHECK_EQ_32 ebx, 0x10

    ;; ================================================================
    ;; ADD16 with register operand (add16 reg,reg path)
    ;; ================================================================

    ; add16 reg carry: 0xFFFF + 0x0002 = 0x0001, CF=1
    ; adc bx, 0: 0x1000 + 0 + 1 = 0x1001
    TEST_CASE t_add16_reg_cf1
    mov ax, 0xFFFF
    mov cx, 0x0002
    add ax, cx              ; CF=1
    call flag_barrier_ret
    mov bx, 0x1000
    adc bx, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, 0

    TEST_CASE t_add16_reg_cf1_r
    CHECK_EQ_32 ebx, 0x1001

    ;; ================================================================
    END_TESTS
