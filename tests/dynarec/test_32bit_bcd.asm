; test_32bit_bcd.asm - Test BCD arithmetic opcodes (32-bit only)
; These opcodes are invalid in 64-bit mode.
;
; Opcodes tested:
;   27 = DAA (Decimal Adjust after Addition)
;   2F = DAS (Decimal Adjust after Subtraction)
;   37 = AAA (ASCII Adjust after Addition)
;   3F = AAS (ASCII Adjust after Subtraction)
;   D4 Ib = AAM (ASCII Adjust after Multiplication)
;   D5 Ib = AAD (ASCII Adjust before Division)

%include "test_framework_32.inc"

section .data
    t1_name:  db "daa basic 09+08=17", 0
    t2_name:  db "daa low nibble >9", 0
    t3_name:  db "daa high nibble >9", 0
    t4_name:  db "daa CF set on >99", 0
    t5_name:  db "das basic 17-08=09", 0
    t6_name:  db "das borrow low nibble", 0
    t7_name:  db "das borrow high", 0
    t8_name:  db "das CF set", 0
    t9_name:  db "aaa basic no adjust", 0
    t10_name: db "aaa low nibble >9", 0
    t11_name: db "aaa AF flag", 0
    t12_name: db "aas basic no adjust", 0
    t13_name: db "aas borrow needed", 0
    t14_name: db "aam base10 59/10=5r9", 0
    t15_name: db "aam base10 0/10=0r0", 0
    t16_name: db "aam base16", 0
    t17_name: db "aam flags ZF", 0
    t18_name: db "aad base10 5*10+9=59", 0
    t19_name: db "aad base10 0*10+0=0", 0
    t20_name: db "aad base16", 0
    t21_name: db "aad flags SF", 0
    t22_name: db "daa chained addition", 0

section .text
global _start

_start:
    INIT_TESTS

    ;; ============ DAA (0x27) ============
    ;; DAA adjusts AL after BCD addition

    ; DAA basic: 0x09 + 0x08 = 0x11 (raw), DAA -> 0x17
    TEST_CASE t1_name
    mov eax, 0x09
    add al, 0x08          ; AL = 0x11
    db 0x27               ; DAA -> AL = 0x17
    movzx ecx, al
    CHECK_EQ_32 ecx, 0x17

    ; DAA low nibble > 9: 0x2C should adjust to 0x32 (add 6 to low nibble)
    TEST_CASE t2_name
    mov eax, 0x18
    add al, 0x14          ; AL = 0x2C
    db 0x27               ; DAA -> AL = 0x32
    movzx ecx, al
    CHECK_EQ_32 ecx, 0x32

    ; DAA high nibble > 9: 0x99 + 0x01 = 0x9A, DAA -> 0x00 with CF
    TEST_CASE t3_name
    mov eax, 0x99
    add al, 0x01          ; AL = 0x9A
    db 0x27               ; DAA -> AL = 0x00 (0x9A + 0x66 = 0x100)
    movzx ecx, al
    CHECK_EQ_32 ecx, 0x00

    ; DAA CF: 0x99 + 0x01 should set CF
    TEST_CASE t4_name
    mov eax, 0x99
    add al, 0x01
    db 0x27
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ;; ============ DAS (0x2F) ============
    ;; DAS adjusts AL after BCD subtraction

    ; DAS basic: 0x17 - 0x08 = 0x0F, DAS -> 0x09
    TEST_CASE t5_name
    mov eax, 0x17
    sub al, 0x08          ; AL = 0x0F
    db 0x2F               ; DAS -> AL = 0x09
    movzx ecx, al
    CHECK_EQ_32 ecx, 0x09

    ; DAS borrow low nibble: 0x20 - 0x13 = 0x0D, DAS -> 0x07
    TEST_CASE t6_name
    mov eax, 0x20
    sub al, 0x13          ; AL = 0x0D
    db 0x2F               ; DAS -> AL = 0x07
    movzx ecx, al
    CHECK_EQ_32 ecx, 0x07

    ; DAS borrow high: 0x00 - 0x01 = 0xFF, DAS -> 0x99
    TEST_CASE t7_name
    mov eax, 0x00
    sub al, 0x01          ; AL = 0xFF, CF=1
    db 0x2F               ; DAS -> AL = 0x99
    movzx ecx, al
    CHECK_EQ_32 ecx, 0x99

    ; DAS CF: should be set after the above
    TEST_CASE t8_name
    mov eax, 0x00
    sub al, 0x01
    db 0x2F
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ;; ============ AAA (0x37) ============
    ;; AAA adjusts AX after unpacked BCD addition

    ; AAA no adjust needed: low nibble of AL <= 9, AF clear
    TEST_CASE t9_name
    mov eax, 0x0005       ; AX = 0x0005
    add al, 0x03          ; AL = 0x08, no carry, AF=0
    db 0x37               ; AAA -> AL = 0x08, AH unchanged
    movzx ecx, al
    and ecx, 0x0F         ; low nibble
    CHECK_EQ_32 ecx, 0x08

    ; AAA adjust needed: low nibble > 9
    TEST_CASE t10_name
    mov eax, 0x0009       ; AX = 0x0009
    add al, 0x05          ; AL = 0x0E (>9), AF set
    db 0x37               ; AAA -> AL = (0x0E+6)&0x0F = 0x04, AH += 1
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0104

    ; AAA sets AF and CF when adjustment happens
    TEST_CASE t11_name
    mov eax, 0x0009
    add al, 0x05
    db 0x37
    SAVE_FLAGS
    CHECK_FLAGS_EQ (AF|CF), (AF|CF)

    ;; ============ AAS (0x3F) ============
    ;; AAS adjusts AX after unpacked BCD subtraction

    ; AAS no adjust needed
    TEST_CASE t12_name
    mov eax, 0x0008
    sub al, 0x03          ; AL = 0x05, AF=0
    db 0x3F               ; AAS -> AL = 0x05, no change
    movzx ecx, al
    and ecx, 0x0F
    CHECK_EQ_32 ecx, 0x05

    ; AAS borrow: 0x0003 - 0x0005 = 0x00FE (with sub), AAS adjusts
    TEST_CASE t13_name
    mov eax, 0x0103       ; AH=1, AL=3
    sub al, 0x05          ; AL = 0xFE, AF=1
    db 0x3F               ; AAS -> AL = (0xFE-6)&0x0F = 0x08, AH -= 1 -> AH=0
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0008

    ;; ============ AAM (0xD4 Ib) ============
    ;; AAM: AH = AL / base, AL = AL % base (default base=10)

    ; AAM base 10: AL=59 -> AH=5, AL=9
    TEST_CASE t14_name
    mov eax, 59           ; AL = 59 = 0x3B
    db 0xD4, 0x0A         ; AAM 10
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0509

    ; AAM base 10: AL=0 -> AH=0, AL=0
    TEST_CASE t15_name
    mov eax, 0
    db 0xD4, 0x0A         ; AAM 10
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0000

    ; AAM base 16: AL=0x2B (43) -> AH=43/16=2, AL=43%16=11=0x0B
    TEST_CASE t16_name
    mov eax, 0x2B
    db 0xD4, 0x10         ; AAM 16
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x020B

    ; AAM flags: ZF when result AL=0
    TEST_CASE t17_name
    mov eax, 0
    db 0xD4, 0x0A         ; AAM 10 -> AH=0, AL=0
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ;; ============ AAD (0xD5 Ib) ============
    ;; AAD: AL = AH * base + AL, AH = 0

    ; AAD base 10: AH=5, AL=9 -> AL = 5*10+9 = 59 = 0x3B, AH=0
    TEST_CASE t18_name
    mov eax, 0x0509       ; AH=5, AL=9
    db 0xD5, 0x0A         ; AAD 10
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x003B

    ; AAD base 10: AH=0, AL=0 -> AL=0, AH=0
    TEST_CASE t19_name
    mov eax, 0x0000
    db 0xD5, 0x0A         ; AAD 10
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0000

    ; AAD base 16: AH=2, AL=0x0B -> AL = 2*16+11 = 43 = 0x2B, AH=0
    TEST_CASE t20_name
    mov eax, 0x020B
    db 0xD5, 0x10         ; AAD 16
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x002B

    ; AAD flags: SF when result >= 0x80
    TEST_CASE t21_name
    mov eax, 0x0900       ; AH=9, AL=0 -> 9*10+0 = 90 = 0x5A (positive)
    ; Use AH=0x0D, AL=0 -> 13*10=130=0x82 (negative in signed byte)
    mov eax, 0x0D00
    db 0xD5, 0x0A         ; AAD 10 -> AL = 13*10 = 130 = 0x82
    SAVE_FLAGS
    CHECK_FLAGS_EQ SF, SF

    ;; ============ DAA chained BCD addition ============
    ;; 0x29 + 0x53 = 0x7C (raw), DAA -> 0x82
    TEST_CASE t22_name
    mov eax, 0x29
    add al, 0x53          ; AL = 0x7C
    db 0x27               ; DAA -> 0x82
    movzx ecx, al
    CHECK_EQ_32 ecx, 0x82

    END_TESTS
