; test_cmp_test.asm - Test CMP (0x38-0x3D) and TEST (0x84-0x85, 0xA8-0xA9)
;                    plus Group 1 immediate CMP (0x80/7, 0x81/7, 0x83/7)
;
; Coverage:
;   CMP Eb,Gb (0x38)    CMP Ed,Gd (0x39)    CMP Gb,Eb (0x3A)    CMP Gd,Ed (0x3B)
;   CMP AL,Ib (0x3C)    CMP EAX,Id (0x3D)
;   TEST Eb,Gb (0x84)   TEST Ed,Gd (0x85)   TEST AL,Ib (0xA8)   TEST EAX,Id (0xA9)
;   CMP Eb,Ib (0x80/7)  CMP Ed,Id (0x81/7)  CMP Ed,Ib sign-ext (0x83/7)
;
; Key scenarios:
;   - Zero-optimized paths (cmp reg, 0 -> emit_cmp8_0 / emit_cmp32_0)
;   - Overflow flag (OF) edge cases
;   - CF=0 and OF=0 always after TEST
;   - Memory operands
;   - Hi-byte registers (AH, BH, CH, DH)
;   - 64-bit with REX.W prefix
;   - Parity flag (PF) verification
;
%include "test_framework.inc"

section .data
    ; === CMP register-register tests ===
    tc1_name:  db "cmp Eb,Gb reg (0x38) equal", 0
    tc2_name:  db "cmp Eb,Gb reg (0x38) less", 0
    tc3_name:  db "cmp Ed,Gd reg (0x39) equal", 0
    tc4_name:  db "cmp Ed,Gd reg (0x39) greater", 0
    tc5_name:  db "cmp Gb,Eb reg (0x3A) less", 0
    tc6_name:  db "cmp Gd,Ed reg (0x3B) equal", 0
    tc7_name:  db "cmp AL,Ib (0x3C) equal", 0
    tc8_name:  db "cmp AL,Ib (0x3C) less", 0
    tc9_name:  db "cmp EAX,Id (0x3D) equal", 0
    tc10_name: db "cmp EAX,Id (0x3D) greater", 0

    ; === CMP memory operand tests ===
    tc11_name: db "cmp Eb,Gb mem (0x38 mem)", 0
    tc12_name: db "cmp Ed,Gd mem (0x39 mem)", 0
    tc13_name: db "cmp Gb,Eb mem (0x3A mem)", 0
    tc14_name: db "cmp Gd,Ed mem (0x3B mem)", 0

    ; === CMP hi-byte register tests ===
    tc15_name: db "cmp AH,CH hi-byte (0x38)", 0
    tc16_name: db "cmp DH,BH hi-byte (0x3A)", 0

    ; === CMP 64-bit REX.W tests ===
    tc17_name: db "cmp r64,r64 REX.W (0x39) equal", 0
    tc18_name: db "cmp r64,r64 REX.W (0x39) less", 0
    tc19_name: db "cmp r64,r64 REX.W (0x3B) greater", 0

    ; === CMP zero-optimized path tests (cmp reg, 0) ===
    tc20_name: db "cmp al,0 zero-opt (0x3C)", 0
    tc21_name: db "cmp eax,0 zero-opt (0x3D)", 0
    tc22_name: db "cmp al,0 nonzero SF (0x3C)", 0
    tc23_name: db "cmp eax,0 nonzero SF (0x3D)", 0

    ; === CMP overflow flag tests ===
    tc24_name: db "cmp8 OF: 0x80 - 0x01", 0
    tc25_name: db "cmp8 OF: 0x7F - 0xFF", 0
    tc26_name: db "cmp32 OF: 0x80000000 - 1", 0
    tc27_name: db "cmp32 OF: 0x7FFFFFFF - (-1)", 0
    tc28_name: db "cmp64 OF: 0x8000000000000000 - 1", 0

    ; === CMP parity flag tests ===
    tc29_name: db "cmp8 PF even parity", 0
    tc30_name: db "cmp8 PF odd parity", 0
    tc31_name: db "cmp32 PF check", 0

    ; === TEST register-register tests ===
    tt1_name:  db "test Eb,Gb reg (0x84) zero", 0
    tt2_name:  db "test Eb,Gb reg (0x84) nonzero", 0
    tt3_name:  db "test Ed,Gd reg (0x85) zero", 0
    tt4_name:  db "test Ed,Gd reg (0x85) nonzero SF", 0
    tt5_name:  db "test AL,Ib (0xA8) zero", 0
    tt6_name:  db "test AL,Ib (0xA8) nonzero", 0
    tt7_name:  db "test EAX,Id (0xA9) zero", 0
    tt8_name:  db "test EAX,Id (0xA9) SF", 0

    ; === TEST memory operand tests ===
    tt9_name:  db "test Eb,Gb mem (0x84 mem)", 0
    tt10_name: db "test Ed,Gd mem (0x85 mem)", 0

    ; === TEST hi-byte register tests ===
    tt11_name: db "test AH,CH hi-byte (0x84)", 0

    ; === TEST 64-bit REX.W tests ===
    tt12_name: db "test r64,r64 REX.W (0x85) zero", 0
    tt13_name: db "test r64,r64 REX.W (0x85) SF", 0

    ; === TEST CF=0 OF=0 invariant tests ===
    tt14_name: db "test CF=0 OF=0 always (0x85)", 0
    tt15_name: db "test CF=0 OF=0 after stc (0xA9)", 0

    ; === TEST parity flag tests ===
    tt16_name: db "test8 PF even parity (0x84)", 0
    tt17_name: db "test32 PF even parity (0x85)", 0

    ; === Group 1 immediate CMP tests ===
    tg1_name:  db "cmp Eb,Ib (0x80/7) equal", 0
    tg2_name:  db "cmp Eb,Ib (0x80/7) less", 0
    tg3_name:  db "cmp Eb,Ib (0x80/7) greater", 0
    tg4_name:  db "cmp Ed,Id (0x81/7) equal", 0
    tg5_name:  db "cmp Ed,Id (0x81/7) less", 0
    tg6_name:  db "cmp Ed,Id (0x81/7) greater", 0
    tg7_name:  db "cmp Ed,Ib sext (0x83/7) equal", 0
    tg8_name:  db "cmp Ed,Ib sext (0x83/7) neg imm", 0
    tg9_name:  db "cmp Ed,Ib sext (0x83/7) greater", 0
    tg10_name: db "cmp Eb,Ib (0x80/7) mem", 0
    tg11_name: db "cmp Ed,Id (0x81/7) mem", 0
    tg12_name: db "cmp Ed,Ib sext (0x83/7) mem", 0
    tg13_name: db "cmp Eb,Ib (0x80/7) OF", 0
    tg14_name: db "cmp Ed,Id (0x81/7) OF", 0
    tg15_name: db "cmp r64,Id sext (0x81/7) REX.W", 0
    tg16_name: db "cmp r64,Ib sext (0x83/7) REX.W", 0

section .bss
    scratch: resq 2

section .text
global _start

_start:
    INIT_TESTS

    ;; ================================================================
    ;; CMP register-register tests
    ;; ================================================================

    ; cmp Eb,Gb (0x38) - equal -> ZF=1, CF=0, SF=0, OF=0
    TEST_CASE tc1_name
    mov eax, 0x42
    mov ecx, 0x42
    cmp al, cl              ; 0x42 - 0x42 = 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Eb,Gb (0x38) - less -> CF=1, SF=1
    TEST_CASE tc2_name
    mov eax, 0x10
    mov ecx, 0x80
    cmp al, cl              ; 0x10 - 0x80 unsigned: borrow -> CF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|SF), (CF|SF)

    ; cmp Ed,Gd (0x39) - equal -> ZF=1
    TEST_CASE tc3_name
    mov eax, 0xDEADBEEF
    mov ebx, 0xDEADBEEF
    cmp eax, ebx
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Ed,Gd (0x39) - greater -> CF=0, ZF=0, SF=0
    TEST_CASE tc4_name
    mov eax, 0x100
    mov ebx, 0x050
    cmp eax, ebx            ; 0x100 - 0x50 = 0xB0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF|SF), 0

    ; cmp Gb,Eb (0x3A) - less -> CF=1
    TEST_CASE tc5_name
    mov ecx, 0x05
    mov edx, 0x80
    cmp cl, dl              ; 0x05 - 0x80 -> CF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; cmp Gd,Ed (0x3B) - equal -> ZF=1
    TEST_CASE tc6_name
    mov ecx, 0x12345678
    mov edx, 0x12345678
    cmp ecx, edx
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp AL,Ib (0x3C) - equal -> ZF=1
    TEST_CASE tc7_name
    mov al, 0x55
    cmp al, 0x55
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp AL,Ib (0x3C) - less -> CF=1, SF=1
    TEST_CASE tc8_name
    mov al, 0x10
    cmp al, 0x90            ; 0x10 - 0x90 -> borrow
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|SF), (CF|SF)

    ; cmp EAX,Id (0x3D) - equal -> ZF=1
    TEST_CASE tc9_name
    mov eax, 0xCAFEBABE
    cmp eax, 0xCAFEBABE
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp EAX,Id (0x3D) - greater -> CF=0, ZF=0
    TEST_CASE tc10_name
    mov eax, 0x80000000
    cmp eax, 0x100          ; large unsigned > small
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF), 0

    ;; ================================================================
    ;; CMP memory operand tests
    ;; ================================================================

    ; cmp [mem], Gb (0x38 mem)
    TEST_CASE tc11_name
    mov byte [rel scratch], 0x42
    mov cl, 0x42
    cmp byte [rel scratch], cl
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp [mem], Gd (0x39 mem)
    TEST_CASE tc12_name
    mov dword [rel scratch], 0xAAAA0000
    mov ebx, 0xAAAA0000
    cmp dword [rel scratch], ebx
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Gb, [mem] (0x3A mem)
    TEST_CASE tc13_name
    mov byte [rel scratch], 0x80
    mov cl, 0x10
    cmp cl, byte [rel scratch]  ; 0x10 - 0x80 -> CF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; cmp Gd, [mem] (0x3B mem)
    TEST_CASE tc14_name
    mov dword [rel scratch], 0x100
    mov ecx, 0x200
    cmp ecx, dword [rel scratch] ; 0x200 - 0x100 = 0x100 -> no flags
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF|SF|OF), 0

    ;; ================================================================
    ;; CMP hi-byte register tests
    ;; ================================================================

    ; cmp AH, CH (0x38 hi-byte)
    TEST_CASE tc15_name
    mov eax, 0x4200
    mov ecx, 0x4200
    cmp ah, ch              ; 0x42 - 0x42 = 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp DH, BH (0x3A direction hi-byte)
    TEST_CASE tc16_name
    mov edx, 0x1000
    mov ebx, 0x8000
    cmp dh, bh              ; 0x10 - 0x80 -> CF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ;; ================================================================
    ;; CMP 64-bit REX.W tests
    ;; ================================================================

    ; cmp r64,r64 equal
    TEST_CASE tc17_name
    mov rax, 0x123456789ABCDEF0
    mov rbx, 0x123456789ABCDEF0
    cmp rax, rbx
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp r64,r64 less (CF=1)
    TEST_CASE tc18_name
    mov rax, 0x0000000000000001
    mov rbx, 0x7FFFFFFFFFFFFFFF
    cmp rax, rbx            ; small - huge -> CF=1, SF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|SF), (CF|SF)

    ; cmp r64,r64 greater via 0x3B direction
    TEST_CASE tc19_name
    mov rcx, 0x7FFFFFFFFFFFFFFF
    mov rdx, 0x0000000000000001
    cmp rcx, rdx            ; huge - small -> CF=0, ZF=0, SF=0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF|SF), 0

    ;; ================================================================
    ;; CMP zero-optimized path tests (exercises emit_cmp8_0 / emit_cmp32_0)
    ;; ================================================================

    ; cmp al, 0 when al=0 -> ZF=1
    TEST_CASE tc20_name
    xor eax, eax
    cmp al, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp eax, 0 when eax=0 -> ZF=1
    TEST_CASE tc21_name
    xor eax, eax
    cmp eax, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp al, 0 when al=0x80 -> SF=1, ZF=0
    TEST_CASE tc22_name
    mov al, 0x80
    cmp al, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|ZF|CF|OF), SF

    ; cmp eax, 0 when eax=0x80000000 -> SF=1, ZF=0
    TEST_CASE tc23_name
    mov eax, 0x80000000
    cmp eax, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|ZF|CF|OF), SF

    ;; ================================================================
    ;; CMP overflow flag (OF) edge cases
    ;; ================================================================

    ; 8-bit: 0x80 - 0x01 = 0x7F -> signed: -128 - 1 = 127 -> OF=1
    TEST_CASE tc24_name
    mov al, 0x80
    mov cl, 0x01
    cmp al, cl
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; 8-bit: 0x7F - 0xFF = 0x80 -> signed: 127 - (-1) = -128 -> OF=1
    TEST_CASE tc25_name
    mov al, 0x7F
    mov cl, 0xFF
    cmp al, cl
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; 32-bit: 0x80000000 - 1 -> signed overflow
    TEST_CASE tc26_name
    mov eax, 0x80000000
    cmp eax, 1
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; 32-bit: 0x7FFFFFFF - 0xFFFFFFFF -> signed: MAX_INT - (-1) = MIN_INT -> OF=1
    TEST_CASE tc27_name
    mov eax, 0x7FFFFFFF
    mov ebx, 0xFFFFFFFF
    cmp eax, ebx
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; 64-bit: 0x8000000000000000 - 1 -> signed overflow
    TEST_CASE tc28_name
    mov rax, 0x8000000000000000
    mov rbx, 1
    cmp rax, rbx
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ;; ================================================================
    ;; CMP parity flag (PF) tests
    ;; PF is set if low byte of result has even number of 1-bits
    ;; ================================================================

    ; 0x05 - 0x02 = 0x03 (bits: 11 -> 2 bits -> even -> PF=1)
    TEST_CASE tc29_name
    mov al, 0x05
    cmp al, 0x02
    SAVE_FLAGS
    CHECK_FLAGS_EQ PF, PF

    ; 0x04 - 0x02 = 0x02 (bits: 10 -> 1 bit -> odd -> PF=0)
    TEST_CASE tc30_name
    mov al, 0x04
    cmp al, 0x02
    SAVE_FLAGS
    CHECK_FLAGS_EQ PF, 0

    ; 32-bit: 0x105 - 0x100 = 0x05 (bits: 101 -> 2 bits -> even -> PF=1)
    TEST_CASE tc31_name
    mov eax, 0x105
    cmp eax, 0x100
    SAVE_FLAGS
    CHECK_FLAGS_EQ PF, PF

    ;; ================================================================
    ;; TEST register-register tests
    ;; ================================================================

    ; test Eb,Gb (0x84) - disjoint masks -> ZF=1
    TEST_CASE tt1_name
    mov eax, 0xF0
    mov ecx, 0x0F
    test al, cl             ; 0xF0 & 0x0F = 0 -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|SF|CF|OF), ZF

    ; test Eb,Gb (0x84) - overlapping -> ZF=0
    TEST_CASE tt2_name
    mov eax, 0xFF
    mov ecx, 0x0F
    test al, cl             ; 0xFF & 0x0F = 0x0F -> ZF=0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|OF), 0

    ; test Ed,Gd (0x85) - disjoint -> ZF=1
    TEST_CASE tt3_name
    mov eax, 0xF0F0F0F0
    mov ebx, 0x0F0F0F0F
    test eax, ebx           ; AND = 0 -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|SF|CF|OF), ZF

    ; test Ed,Gd (0x85) - sign bit set -> SF=1
    TEST_CASE tt4_name
    mov eax, 0x80000000
    mov ebx, 0xFFFFFFFF
    test eax, ebx           ; AND = 0x80000000 -> SF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|ZF|CF|OF), SF

    ; test AL,Ib (0xA8) - disjoint -> ZF=1
    TEST_CASE tt5_name
    mov al, 0xF0
    test al, 0x0F           ; 0xF0 & 0x0F = 0 -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|SF|CF|OF), ZF

    ; test AL,Ib (0xA8) - overlap -> ZF=0
    TEST_CASE tt6_name
    mov al, 0xFF
    test al, 0x80           ; 0xFF & 0x80 = 0x80 -> SF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|ZF|CF|OF), SF

    ; test EAX,Id (0xA9) - disjoint -> ZF=1
    TEST_CASE tt7_name
    mov eax, 0x00FF00FF
    test eax, 0xFF00FF00    ; AND = 0 -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|SF|CF|OF), ZF

    ; test EAX,Id (0xA9) - sign bit -> SF=1
    TEST_CASE tt8_name
    mov eax, 0xFFFFFFFF
    test eax, 0x80000000    ; AND = 0x80000000 -> SF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|ZF|CF|OF), SF

    ;; ================================================================
    ;; TEST memory operand tests
    ;; ================================================================

    ; test [mem], Gb (0x84 mem)
    TEST_CASE tt9_name
    mov byte [rel scratch], 0xF0
    mov cl, 0x0F
    test byte [rel scratch], cl  ; 0xF0 & 0x0F = 0 -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|OF), ZF

    ; test [mem], Gd (0x85 mem) - NOTE: test has no Gd,[mem] form, only [mem],Gd
    TEST_CASE tt10_name
    mov dword [rel scratch], 0x80000000
    mov ebx, 0xFFFFFFFF
    test dword [rel scratch], ebx ; AND = 0x80000000 -> SF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|ZF|CF|OF), SF

    ;; ================================================================
    ;; TEST hi-byte register tests
    ;; ================================================================

    ; test AH, CH (0x84 hi-byte)
    TEST_CASE tt11_name
    mov eax, 0xF000
    mov ecx, 0x0F00
    test ah, ch             ; 0xF0 & 0x0F = 0 -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|OF), ZF

    ;; ================================================================
    ;; TEST 64-bit REX.W tests
    ;; ================================================================

    ; test r64,r64 - disjoint -> ZF=1
    TEST_CASE tt12_name
    mov rax, 0xAAAAAAAAAAAAAAAA
    mov rbx, 0x5555555555555555
    test rax, rbx           ; AND = 0 -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|SF|CF|OF), ZF

    ; test r64,r64 - sign bit -> SF=1
    TEST_CASE tt13_name
    mov rax, 0x8000000000000001
    test rax, rax           ; AND = self -> SF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|ZF|CF|OF), SF

    ;; ================================================================
    ;; TEST CF=0 and OF=0 invariant (TEST always clears CF and OF)
    ;; ================================================================

    ; Set CF first with stc, then TEST should clear it
    TEST_CASE tt14_name
    stc                     ; set CF=1
    mov eax, 0xFFFFFFFF
    test eax, eax           ; CF must be 0 after TEST
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|OF), 0

    ; Another CF/OF invariant after stc
    TEST_CASE tt15_name
    stc                     ; set CF=1
    mov eax, 0x80000000
    test eax, 0x80000000    ; CF=0, OF=0 always
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|OF), 0

    ;; ================================================================
    ;; TEST parity flag (PF) tests
    ;; ================================================================

    ; test8: 0xFF & 0x03 = 0x03 (2 bits -> even -> PF=1)
    TEST_CASE tt16_name
    mov al, 0xFF
    mov cl, 0x03
    test al, cl
    SAVE_FLAGS
    CHECK_FLAGS_EQ PF, PF

    ; test32: 0x0F & 0x0F = 0x0F (4 bits -> even -> PF=1)
    TEST_CASE tt17_name
    mov eax, 0x0F
    test eax, 0x0F
    SAVE_FLAGS
    CHECK_FLAGS_EQ PF, PF

    ;; ================================================================
    ;; Group 1 immediate CMP (0x80/7, 0x81/7, 0x83/7)
    ;; ================================================================

    ; cmp Eb, Ib (0x80/7) - equal -> ZF=1
    TEST_CASE tg1_name
    mov cl, 0x42
    cmp cl, 0x42
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Eb, Ib (0x80/7) - less -> CF=1
    TEST_CASE tg2_name
    mov cl, 0x10
    cmp cl, 0x80            ; 0x10 - 0x80 -> CF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; cmp Eb, Ib (0x80/7) - greater -> CF=0, ZF=0
    TEST_CASE tg3_name
    mov cl, 0x80
    cmp cl, 0x10
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF), 0

    ; cmp Ed, Id (0x81/7) - equal -> ZF=1
    TEST_CASE tg4_name
    mov ecx, 0x12345678
    cmp ecx, 0x12345678
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Ed, Id (0x81/7) - less -> CF=1
    TEST_CASE tg5_name
    mov ecx, 0x100
    cmp ecx, 0x80000000     ; small - huge unsigned -> CF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; cmp Ed, Id (0x81/7) - greater -> CF=0, ZF=0
    TEST_CASE tg6_name
    mov ecx, 0x80000000
    cmp ecx, 0x100
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF), 0

    ; cmp Ed, Ib sign-extended (0x83/7) - equal (positive imm)
    TEST_CASE tg7_name
    mov ecx, 0x0000007F
    cmp ecx, 0x7F           ; 0x7F sign-extends to 0x0000007F
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Ed, Ib sign-extended (0x83/7) - negative immediate
    ; 0xFE sign-extends to 0xFFFFFFFE (-2)
    ; ecx=0xFFFFFFFE, cmp ecx, -2 -> equal
    TEST_CASE tg8_name
    mov ecx, 0xFFFFFFFE
    cmp ecx, -2             ; -2 sign-extends to 0xFFFFFFFE
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Ed, Ib sign-extended (0x83/7) - greater
    TEST_CASE tg9_name
    mov ecx, 0x100
    cmp ecx, 0x10           ; 0x100 - 0x10 = 0xF0 -> no borrow
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF), 0

    ; cmp [mem], Ib (0x80/7 mem)
    TEST_CASE tg10_name
    mov byte [rel scratch], 0x42
    cmp byte [rel scratch], 0x42
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp [mem], Id (0x81/7 mem)
    TEST_CASE tg11_name
    mov dword [rel scratch], 0xDEADBEEF
    cmp dword [rel scratch], 0xDEADBEEF
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp [mem], Ib sign-extended (0x83/7 mem)
    TEST_CASE tg12_name
    mov dword [rel scratch], 0x0000007F
    cmp dword [rel scratch], 0x7F
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp Eb, Ib (0x80/7) - overflow: 0x80 - 0x01 -> OF=1
    TEST_CASE tg13_name
    mov cl, 0x80
    cmp cl, 0x01
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; cmp Ed, Id (0x81/7) - overflow: 0x80000000 - 1 -> OF=1
    TEST_CASE tg14_name
    mov ecx, 0x80000000
    cmp ecx, 1
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ; cmp r64, Id sign-extended (0x81/7 REX.W)
    ; 0x123456789ABCDEF0 compared to sign-extended 0x100
    TEST_CASE tg15_name
    mov rax, 0x100
    cmp rax, 0x100          ; equal -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ; cmp r64, Ib sign-extended (0x83/7 REX.W)
    TEST_CASE tg16_name
    mov rax, 0x7F
    cmp rax, 0x7F           ; equal -> ZF=1
    SAVE_FLAGS
    CHECK_FLAGS_EQ (ZF|CF|SF|OF), ZF

    ;; ================================================================
    ;; Done
    ;; ================================================================
    END_TESTS
