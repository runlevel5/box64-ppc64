; test_16bit_alu.asm - Test 16-bit (66-prefix) ALU operations
; Covers: ADD/SUB/OR/AND/XOR/CMP/ADC/SBB/shifts/INC/DEC/NEG/NOT/MUL/IMUL/DIV Ew
; These are all 66-prefixed opcodes in the dynarec
%include "test_framework.inc"

section .data
    t1_name:  db "add16 Ew,Gw basic", 0
    t2_name:  db "add16 Gw,Ew basic", 0
    t3_name:  db "add16 AX,Iw carry", 0
    t4_name:  db "add16 overflow OF", 0
    t5_name:  db "sub16 Ew,Gw basic", 0
    t6_name:  db "sub16 Gw,Ew borrow", 0
    t7_name:  db "sub16 AX,Iw", 0
    t8_name:  db "or16 Ew,Gw", 0
    t9_name:  db "or16 Gw,Ew", 0
    t10_name: db "or16 AX,Iw", 0
    t11_name: db "and16 Ew,Gw", 0
    t12_name: db "and16 Gw,Ew", 0
    t13_name: db "and16 AX,Iw", 0
    t14_name: db "xor16 Ew,Gw", 0
    t15_name: db "xor16 Gw,Ew self=0", 0
    t16_name: db "xor16 AX,Iw", 0
    t17_name: db "cmp16 Ew,Gw equal ZF", 0
    t18_name: db "cmp16 Gw,Ew less SF+CF", 0
    t19_name: db "cmp16 AX,Iw", 0
    t20_name: db "adc16 carry in", 0
    t21_name: db "adc16 carry out", 0
    t22_name: db "sbb16 borrow in", 0
    t23_name: db "sbb16 borrow out", 0
    t24_name: db "shl16 Ew,Ib", 0
    t25_name: db "shr16 Ew,Ib", 0
    t26_name: db "sar16 Ew,Ib", 0
    t27_name: db "shl16 Ew,1", 0
    t28_name: db "shr16 Ew,CL", 0
    t29_name: db "rol16 Ew,Ib", 0
    t30_name: db "ror16 Ew,Ib", 0
    t31_name: db "grp1 add16 Ew,Iw", 0
    t32_name: db "grp1 sub16 Ew,Ib", 0
    t33_name: db "grp1 cmp16 Ew,Iw", 0
    t34_name: db "test16 Ew,Gw", 0
    t35_name: db "test16 AX,Iw", 0
    t36_name: db "inc16 via grp5", 0
    t37_name: db "dec16 via grp5", 0
    t38_name: db "neg16 via grp3", 0
    t39_name: db "not16 via grp3", 0
    t40_name: db "mul16 AX*r16", 0
    t41_name: db "imul16 Gw,Ew", 0
    t42_name: db "imul16 Gw,Ew,Iw", 0
    t43_name: db "imul16 Gw,Ew,Ib", 0
    t44_name: db "div16 DX:AX/r16", 0

section .bss
    scratch: resq 2

section .text
global _start

_start:
    INIT_TESTS

    ;; ============ ADD 16-bit ============

    ; add Ew,Gw: 0x100 + 0x200 = 0x300
    TEST_CASE t1_name
    mov ax, 0x100
    mov bx, 0x200
    add ax, bx
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x300

    ; add Gw,Ew: 0x1234 + 0x4321 = 0x5555
    TEST_CASE t2_name
    mov word [rel scratch], 0x4321
    mov ax, 0x1234
    add ax, word [rel scratch]
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x5555

    ; add AX,Iw: 0xFFF0 + 0x0020 = 0x0010, CF=1
    TEST_CASE t3_name
    mov ax, 0xFFF0
    add ax, 0x0020
    SAVE_FLAGS
    CHECK_FLAGS_EQ CF, CF

    ; add16 overflow: 0x7FFF + 1 = 0x8000, OF=1
    TEST_CASE t4_name
    mov ax, 0x7FFF
    add ax, 1
    SAVE_FLAGS
    CHECK_FLAGS_EQ OF, OF

    ;; ============ SUB 16-bit ============

    ; sub Ew,Gw: 0x500 - 0x200 = 0x300
    TEST_CASE t5_name
    mov ax, 0x500
    mov bx, 0x200
    sub ax, bx
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x300

    ; sub Gw,Ew: 0x100 - 0x200 => CF=1, SF=1
    TEST_CASE t6_name
    mov ax, 0x100
    mov bx, 0x200
    sub ax, bx
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|SF), (CF|SF)

    ; sub AX,Iw: 0x1000 - 0x1000 = 0, ZF=1
    TEST_CASE t7_name
    mov ax, 0x1000
    sub ax, 0x1000
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ;; ============ OR 16-bit ============

    ; or Ew,Gw: 0xF0F0 | 0x0F0F = 0xFFFF
    TEST_CASE t8_name
    mov ax, 0xF0F0
    mov bx, 0x0F0F
    or ax, bx
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xFFFF

    ; or Gw,Ew from mem
    TEST_CASE t9_name
    mov word [rel scratch], 0x00FF
    mov ax, 0xFF00
    or ax, word [rel scratch]
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xFFFF

    ; or AX,Iw: 0x1234 | 0x4321 = 0x5335
    TEST_CASE t10_name
    mov ax, 0x1234
    or ax, 0x4321
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x5335

    ;; ============ AND 16-bit ============

    ; and Ew,Gw: 0xFFFF & 0x00FF = 0x00FF
    TEST_CASE t11_name
    mov ax, 0xFFFF
    mov bx, 0x00FF
    and ax, bx
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x00FF

    ; and Gw,Ew from mem
    TEST_CASE t12_name
    mov word [rel scratch], 0xF0F0
    mov ax, 0xFF00
    and ax, word [rel scratch]
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xF000

    ; and AX,Iw: 0x1234 & 0xF00F = 0x1004
    TEST_CASE t13_name
    mov ax, 0x1234
    and ax, 0xF00F
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x1004

    ;; ============ XOR 16-bit ============

    ; xor Ew,Gw: 0xAAAA ^ 0x5555 = 0xFFFF
    TEST_CASE t14_name
    mov ax, 0xAAAA
    mov bx, 0x5555
    xor ax, bx
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xFFFF

    ; xor Gw,Ew self = 0, ZF=1
    TEST_CASE t15_name
    mov ax, 0x1234
    xor ax, ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ; xor AX,Iw: 0xFFFF ^ 0x00FF = 0xFF00
    TEST_CASE t16_name
    mov ax, 0xFFFF
    xor ax, 0x00FF
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xFF00

    ;; ============ CMP 16-bit ============

    ; cmp Ew,Gw: equal -> ZF=1
    TEST_CASE t17_name
    mov ax, 0x1234
    mov bx, 0x1234
    cmp ax, bx
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ; cmp Gw,Ew: 0x100 < 0x200 -> SF=1, CF=1
    TEST_CASE t18_name
    mov ax, 0x100
    mov bx, 0x200
    cmp ax, bx
    SAVE_FLAGS
    CHECK_FLAGS_EQ (SF|CF), (SF|CF)

    ; cmp AX,Iw: 0x5678 - 0x5678 = 0, ZF=1
    TEST_CASE t19_name
    mov ax, 0x5678
    cmp ax, 0x5678
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ;; ============ ADC 16-bit ============

    ; adc16 carry in: stc, 0x100 + 0x200 + 1 = 0x301
    TEST_CASE t20_name
    stc
    mov ax, 0x100
    adc ax, 0x200
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x301

    ; adc16 carry out: 0xFFFF + 0 + 1(CF) = 0, CF=1, ZF=1
    TEST_CASE t21_name
    stc
    mov ax, 0xFFFF
    adc ax, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|ZF), (CF|ZF)

    ;; ============ SBB 16-bit ============

    ; sbb16 borrow in: stc, 0x300 - 0x100 - 1 = 0x1FF
    TEST_CASE t22_name
    stc
    mov ax, 0x300
    sbb ax, 0x100
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x1FF

    ; sbb16 borrow out: 0x0000 - 0x0000 - 1(CF) = 0xFFFF, CF=1, SF=1
    TEST_CASE t23_name
    stc
    mov ax, 0x0000
    sbb ax, 0
    SAVE_FLAGS
    CHECK_FLAGS_EQ (CF|SF), (CF|SF)

    ;; ============ Shifts 16-bit ============

    ; shl Ew,Ib: 0x0001 << 4 = 0x0010
    TEST_CASE t24_name
    mov ax, 0x0001
    shl ax, 4
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0010

    ; shr Ew,Ib: 0x8000 >> 4 = 0x0800
    TEST_CASE t25_name
    mov ax, 0x8000
    shr ax, 4
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0800

    ; sar Ew,Ib: 0x8000 >> 4 (arithmetic) = 0xF800
    TEST_CASE t26_name
    mov ax, 0x8000
    sar ax, 4
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xF800

    ; shl Ew,1: 0x4000 << 1 = 0x8000, CF=0
    TEST_CASE t27_name
    mov ax, 0x4000
    shl ax, 1
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x8000

    ; shr Ew,CL: 0xFF00 >> 8 = 0x00FF
    TEST_CASE t28_name
    mov ax, 0xFF00
    mov cl, 8
    shr ax, cl
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x00FF

    ; rol Ew,Ib: 0x8001 rol 4 = 0x0018
    TEST_CASE t29_name
    mov ax, 0x8001
    rol ax, 4
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0018

    ; ror Ew,Ib: 0x8001 ror 4 = 0x1800
    TEST_CASE t30_name
    mov ax, 0x8001
    ror ax, 4
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x1800

    ;; ============ Group 1 16-bit (0x81, 0x83) ============

    ; grp1 add Ew,Iw (0x81/0): 0x1000 + 0x2345 = 0x3345
    TEST_CASE t31_name
    mov ax, 0x1000
    add ax, 0x2345
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x3345

    ; grp1 sub Ew,Ib (0x83/5): 0x100 - 0x10 = 0xF0
    TEST_CASE t32_name
    mov ax, 0x100
    sub ax, 0x10
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x00F0

    ; grp1 cmp Ew,Iw (0x81/7): 0xABCD - 0xABCD = 0, ZF=1
    TEST_CASE t33_name
    mov ax, 0xABCD
    cmp ax, 0xABCD
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ;; ============ TEST 16-bit ============

    ; test Ew,Gw: 0xF0F0 & 0x0F0F = 0, ZF=1
    TEST_CASE t34_name
    mov ax, 0xF0F0
    mov bx, 0x0F0F
    test ax, bx
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ; test AX,Iw: 0xFF00 & 0x00FF = 0, ZF=1
    TEST_CASE t35_name
    mov ax, 0xFF00
    test ax, 0x00FF
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ;; ============ INC/DEC/NEG/NOT 16-bit via GRP3/GRP5 ============

    ; inc16: 0xFFFE + 1 = 0xFFFF, SF=1
    TEST_CASE t36_name
    mov ax, 0xFFFE
    inc ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ SF, SF

    ; dec16: 0x0001 - 1 = 0, ZF=1
    TEST_CASE t37_name
    mov ax, 0x0001
    dec ax
    SAVE_FLAGS
    CHECK_FLAGS_EQ ZF, ZF

    ; neg16: neg 0x0001 = 0xFFFF, CF=1, SF=1
    TEST_CASE t38_name
    mov ax, 0x0001
    neg ax
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xFFFF

    ; not16: not 0xAAAA = 0x5555
    TEST_CASE t39_name
    mov ax, 0xAAAA
    not ax
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x5555

    ;; ============ MUL/IMUL/DIV 16-bit ============

    ; mul16: AX * r16 -> DX:AX. 0x100 * 0x100 = 0x10000
    ; DX=0x0001, AX=0x0000
    TEST_CASE t40_name
    mov ax, 0x100
    mov bx, 0x100
    mul bx
    movzx ecx, dx
    CHECK_EQ_32 ecx, 0x0001

    ; imul16 Gw,Ew: (-7) * 6 = -42 = 0xFFD6
    TEST_CASE t41_name
    mov ax, -7
    mov bx, 6
    imul ax, bx
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0xFFD6

    ; imul16 Gw,Ew,Iw: 100 * 200 = 20000 = 0x4E20
    TEST_CASE t42_name
    mov bx, 100
    imul ax, bx, 200
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x4E20

    ; imul16 Gw,Ew,Ib: 1000 * 7 = 7000 = 0x1B58
    TEST_CASE t43_name
    mov bx, 1000
    imul ax, bx, 7
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x1B58

    ; div16: DX:AX / r16. 0x0001:0x0000 / 0x0100 = 0x100, rem 0
    TEST_CASE t44_name
    mov dx, 0x0001
    mov ax, 0x0000
    mov bx, 0x0100
    div bx
    ; quotient = 0x10000 / 0x100 = 0x100
    movzx ecx, ax
    CHECK_EQ_32 ecx, 0x0100

    END_TESTS
