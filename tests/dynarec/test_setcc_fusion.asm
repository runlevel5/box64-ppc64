; test_setcc_fusion.asm - Test SETcc immediately after flag producers
; Tests in-block fusion: producer -> SETcc (no intervening call/barrier)
;
; Producers tested: CMP, TEST, AND, OR, XOR, ADD, SUB, NEG, INC, DEC
; Conditions tested: sete/setne, sets/setns, setc/setnc, seto/setno,
;                    setl/setge, setle/setg, setb/seta, setbe/setnbe
; Both true (=1) and false (=0) results for each
;
; This exercises the dynarec's NATIVESET optimization path

%include "test_framework.inc"

section .data
    ; ---- CMP producers ----
    t01_name: db "CMP32 sete true", 0
    t02_name: db "CMP32 sete false", 0
    t03_name: db "CMP32 setne true", 0
    t04_name: db "CMP32 setne false", 0
    t05_name: db "CMP32 sets true", 0
    t06_name: db "CMP32 sets false", 0
    t07_name: db "CMP32 setns true", 0
    t08_name: db "CMP32 setc true", 0
    t09_name: db "CMP32 setc false", 0
    t10_name: db "CMP32 setnc true", 0
    t11_name: db "CMP32 seto true", 0
    t12_name: db "CMP32 seto false", 0
    t13_name: db "CMP32 setno true", 0
    t14_name: db "CMP32 setl true", 0
    t15_name: db "CMP32 setl false", 0
    t16_name: db "CMP32 setge true", 0
    t17_name: db "CMP32 setle true", 0
    t18_name: db "CMP32 setle false", 0
    t19_name: db "CMP32 setg true", 0
    t20_name: db "CMP32 setg false", 0
    t21_name: db "CMP64 sete true", 0
    t22_name: db "CMP64 sets true", 0
    t23_name: db "CMP32 setbe true", 0
    t24_name: db "CMP32 setbe false", 0
    t25_name: db "CMP32 seta true", 0
    t26_name: db "CMP32 seta false", 0
    ; ---- TEST producers ----
    t27_name: db "TEST32 sete true", 0
    t28_name: db "TEST32 sete false", 0
    t29_name: db "TEST32 sets true", 0
    t30_name: db "TEST32 sets false", 0
    t31_name: db "TEST64 sete true", 0
    t32_name: db "TEST64 sets true", 0
    ; ---- AND producers ----
    t33_name: db "AND32 sete true", 0
    t34_name: db "AND32 sete false", 0
    t35_name: db "AND32 sets true", 0
    t36_name: db "AND32 sets false", 0
    t37_name: db "AND64 sete true", 0
    t38_name: db "AND64 sets true", 0
    ; ---- OR producers ----
    t39_name: db "OR32 sete true", 0
    t40_name: db "OR32 sete false", 0
    t41_name: db "OR32 sets true", 0
    t42_name: db "OR32 sets false", 0
    ; ---- XOR producers ----
    t43_name: db "XOR32 sete true", 0
    t44_name: db "XOR32 sete false", 0
    t45_name: db "XOR32 sets true", 0
    t46_name: db "XOR32 sets false", 0
    ; ---- ADD producers ----
    t47_name: db "ADD32 sete true", 0
    t48_name: db "ADD32 sete false", 0
    t49_name: db "ADD32 sets true", 0
    t50_name: db "ADD32 sets false", 0
    t51_name: db "ADD32 setc true", 0
    t52_name: db "ADD32 setc false", 0
    t53_name: db "ADD32 seto true", 0
    t54_name: db "ADD32 seto false", 0
    ; ---- SUB producers ----
    t55_name: db "SUB32 sete true", 0
    t56_name: db "SUB32 sete false", 0
    t57_name: db "SUB32 sets true", 0
    t58_name: db "SUB32 setc true", 0
    t59_name: db "SUB32 seto true", 0
    t60_name: db "SUB32 setl true", 0
    ; ---- NEG producers ----
    t61_name: db "NEG32 sete true", 0
    t62_name: db "NEG32 sete false", 0
    t63_name: db "NEG32 sets true", 0
    t64_name: db "NEG32 setc true", 0
    t65_name: db "NEG32 setc false", 0
    ; ---- INC/DEC producers ----
    t66_name: db "INC32 sete true", 0
    t67_name: db "INC32 sete false", 0
    t68_name: db "INC32 sets true", 0
    t69_name: db "DEC32 sete true", 0
    t70_name: db "DEC32 sets true", 0
    t71_name: db "DEC32 seto true", 0
    ; ---- 8/16-bit widths ----
    t72_name: db "CMP8 sete true", 0
    t73_name: db "CMP16 sets true", 0
    t74_name: db "TEST8 sete true", 0
    t75_name: db "AND8 sets true", 0
    t76_name: db "ADD8 setc true", 0
    t77_name: db "SUB16 sets true", 0

section .text
global _start

_start:
    INIT_TESTS

    ; ================================================================
    ; CMP producer + SETcc
    ; ================================================================

    ; ---- Test 01: CMP32 sete true ----
    TEST_CASE t01_name
    mov eax, 42
    cmp eax, 42            ; ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 02: CMP32 sete false ----
    TEST_CASE t02_name
    mov eax, 42
    cmp eax, 43            ; ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 03: CMP32 setne true ----
    TEST_CASE t03_name
    mov eax, 42
    cmp eax, 43            ; ZF=0
    setne cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 04: CMP32 setne false ----
    TEST_CASE t04_name
    mov eax, 42
    cmp eax, 42            ; ZF=1
    setne cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 05: CMP32 sets true ----
    TEST_CASE t05_name
    mov eax, 5
    cmp eax, 100           ; 5-100 < 0 -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 06: CMP32 sets false ----
    TEST_CASE t06_name
    mov eax, 100
    cmp eax, 5             ; 100-5 > 0 -> SF=0
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 07: CMP32 setns true ----
    TEST_CASE t07_name
    mov eax, 100
    cmp eax, 5             ; SF=0
    setns cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 08: CMP32 setc true (borrow) ----
    TEST_CASE t08_name
    mov eax, 5
    cmp eax, 100           ; 5 < 100 -> CF=1
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 09: CMP32 setc false ----
    TEST_CASE t09_name
    mov eax, 100
    cmp eax, 5             ; 100 >= 5 -> CF=0
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 10: CMP32 setnc true ----
    TEST_CASE t10_name
    mov eax, 100
    cmp eax, 5             ; CF=0
    setnc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 11: CMP32 seto true ----
    TEST_CASE t11_name
    mov eax, 0x80000000    ; INT_MIN
    cmp eax, 1             ; INT_MIN - 1 overflows -> OF=1
    seto cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 12: CMP32 seto false ----
    TEST_CASE t12_name
    mov eax, 42
    cmp eax, 10            ; no overflow -> OF=0
    seto cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 13: CMP32 setno true ----
    TEST_CASE t13_name
    mov eax, 42
    cmp eax, 10            ; OF=0
    setno cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 14: CMP32 setl true (SF!=OF) ----
    TEST_CASE t14_name
    mov eax, -5
    cmp eax, 3             ; -5 < 3
    setl cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 15: CMP32 setl false ----
    TEST_CASE t15_name
    mov eax, 10
    cmp eax, 3             ; 10 >= 3
    setl cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 16: CMP32 setge true ----
    TEST_CASE t16_name
    mov eax, 10
    cmp eax, 3             ; 10 >= 3
    setge cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 17: CMP32 setle true (ZF=1 or SF!=OF) ----
    TEST_CASE t17_name
    mov eax, 3
    cmp eax, 3             ; equal -> ZF=1
    setle cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 18: CMP32 setle false ----
    TEST_CASE t18_name
    mov eax, 10
    cmp eax, 3             ; 10 > 3 -> ZF=0, SF=OF -> setle=0
    setle cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 19: CMP32 setg true (ZF=0 and SF=OF) ----
    TEST_CASE t19_name
    mov eax, 10
    cmp eax, 3             ; 10 > 3
    setg cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 20: CMP32 setg false ----
    TEST_CASE t20_name
    mov eax, 3
    cmp eax, 3             ; equal -> ZF=1 -> setg=0
    setg cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 21: CMP64 sete true ----
    TEST_CASE t21_name
    mov rax, 0x100000000
    mov rbx, 0x100000000
    cmp rax, rbx           ; ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 22: CMP64 sets true ----
    TEST_CASE t22_name
    mov rax, 5
    mov rbx, 0x7FFFFFFFFFFFFFFF
    cmp rax, rbx           ; negative result -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 23: CMP32 setbe true (CF=1 or ZF=1) ----
    TEST_CASE t23_name
    mov eax, 5
    cmp eax, 5             ; equal -> ZF=1
    setbe cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 24: CMP32 setbe false ----
    TEST_CASE t24_name
    mov eax, 100
    cmp eax, 5             ; 100 > 5 unsigned -> CF=0, ZF=0
    setbe cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 25: CMP32 seta true (CF=0 and ZF=0) ----
    TEST_CASE t25_name
    mov eax, 100
    cmp eax, 5
    seta cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 26: CMP32 seta false (equal -> ZF=1) ----
    TEST_CASE t26_name
    mov eax, 5
    cmp eax, 5
    seta cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ================================================================
    ; TEST producer + SETcc
    ; ================================================================

    ; ---- Test 27: TEST32 sete true ----
    TEST_CASE t27_name
    mov eax, 0xFF00
    test eax, 0x00FF       ; AND=0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 28: TEST32 sete false ----
    TEST_CASE t28_name
    mov eax, 0xFF
    test eax, 0xFF         ; AND!=0 -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 29: TEST32 sets true ----
    TEST_CASE t29_name
    mov eax, 0x80000000
    test eax, eax          ; bit 31 set -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 30: TEST32 sets false ----
    TEST_CASE t30_name
    mov eax, 0x7FFFFFFF
    test eax, eax          ; bit 31 clear -> SF=0
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 31: TEST64 sete true ----
    TEST_CASE t31_name
    mov rax, 0xFF00000000
    mov rbx, 0x00FFFFFFFF
    test rax, rbx          ; no overlap -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 32: TEST64 sets true ----
    TEST_CASE t32_name
    mov rax, 0x8000000000000000
    test rax, rax          ; bit 63 set -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; AND producer + SETcc
    ; ================================================================

    ; ---- Test 33: AND32 sete true ----
    TEST_CASE t33_name
    mov eax, 0xFF00
    and eax, 0x00FF        ; result=0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 34: AND32 sete false ----
    TEST_CASE t34_name
    mov eax, 0xFFFF
    and eax, 0x00FF        ; result=0xFF -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 35: AND32 sets true ----
    TEST_CASE t35_name
    mov eax, 0x80000000
    mov ebx, 0xF0000000
    and eax, ebx           ; bit 31 set -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 36: AND32 sets false ----
    TEST_CASE t36_name
    mov eax, 0x7FFFFFFF
    mov ebx, 0x0FFFFFFF
    and eax, ebx           ; bit 31 clear -> SF=0
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 37: AND64 sete true ----
    TEST_CASE t37_name
    mov rax, 0xFF00000000
    mov rbx, 0x00FFFFFFFF
    and rax, rbx           ; no overlap -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 38: AND64 sets true ----
    TEST_CASE t38_name
    mov rax, 0x8000000000000000
    mov rbx, 0xF000000000000000
    and rax, rbx           ; bit 63 set -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; OR producer + SETcc
    ; ================================================================

    ; ---- Test 39: OR32 sete true ----
    TEST_CASE t39_name
    xor eax, eax
    or eax, 0              ; 0|0=0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 40: OR32 sete false ----
    TEST_CASE t40_name
    mov eax, 1
    or eax, 0              ; 1|0=1 -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 41: OR32 sets true ----
    TEST_CASE t41_name
    mov eax, 0x80000000
    or eax, 0              ; bit 31 set -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 42: OR32 sets false ----
    TEST_CASE t42_name
    mov eax, 0x7FFFFFFF
    or eax, 0              ; bit 31 clear -> SF=0
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ================================================================
    ; XOR producer + SETcc
    ; ================================================================

    ; ---- Test 43: XOR32 sete true ----
    TEST_CASE t43_name
    mov eax, 42
    xor eax, eax           ; 0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 44: XOR32 sete false ----
    TEST_CASE t44_name
    mov eax, 0xFF
    xor eax, 0x0F          ; 0xF0 -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 45: XOR32 sets true ----
    TEST_CASE t45_name
    mov eax, 0x7FFFFFFF
    mov ebx, 0xFFFFFFFF
    xor eax, ebx           ; 0x80000000 -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 46: XOR32 sets false ----
    TEST_CASE t46_name
    mov eax, 0xFF
    xor eax, 0x0F          ; 0xF0 -> SF=0
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ================================================================
    ; ADD producer + SETcc
    ; ================================================================

    ; ---- Test 47: ADD32 sete true ----
    TEST_CASE t47_name
    mov eax, 5
    add eax, -5            ; 0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 48: ADD32 sete false ----
    TEST_CASE t48_name
    mov eax, 5
    add eax, 1             ; 6 -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 49: ADD32 sets true ----
    TEST_CASE t49_name
    mov eax, 0x7FFFFFFF
    add eax, 1             ; wraps to 0x80000000 -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 50: ADD32 sets false ----
    TEST_CASE t50_name
    mov eax, 5
    add eax, 10            ; 15 -> SF=0
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 51: ADD32 setc true ----
    TEST_CASE t51_name
    mov eax, 0xFFFFFFFF
    add eax, 1             ; wraps -> CF=1
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 52: ADD32 setc false ----
    TEST_CASE t52_name
    mov eax, 5
    add eax, 10            ; no carry -> CF=0
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 53: ADD32 seto true ----
    TEST_CASE t53_name
    mov eax, 0x7FFFFFFF
    add eax, 1             ; INT_MAX+1 overflows -> OF=1
    seto cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 54: ADD32 seto false ----
    TEST_CASE t54_name
    mov eax, 5
    add eax, 10            ; no overflow -> OF=0
    seto cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ================================================================
    ; SUB producer + SETcc
    ; ================================================================

    ; ---- Test 55: SUB32 sete true ----
    TEST_CASE t55_name
    mov eax, 42
    sub eax, 42            ; 0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 56: SUB32 sete false ----
    TEST_CASE t56_name
    mov eax, 42
    sub eax, 10            ; 32 -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 57: SUB32 sets true ----
    TEST_CASE t57_name
    mov eax, 5
    sub eax, 10            ; -5 -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 58: SUB32 setc true ----
    TEST_CASE t58_name
    mov eax, 5
    sub eax, 10            ; 5 < 10 -> CF=1
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 59: SUB32 seto true ----
    TEST_CASE t59_name
    mov eax, 0x80000000
    sub eax, 1             ; INT_MIN - 1 overflows -> OF=1
    seto cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 60: SUB32 setl true ----
    TEST_CASE t60_name
    mov eax, -5
    sub eax, 3             ; -8 -> SF=1, OF=0 -> SF!=OF -> setl=1
    setl cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; NEG producer + SETcc
    ; ================================================================

    ; ---- Test 61: NEG32 sete true ----
    TEST_CASE t61_name
    xor eax, eax
    neg eax                ; neg(0) = 0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 62: NEG32 sete false ----
    TEST_CASE t62_name
    mov eax, 5
    neg eax                ; -5 -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 63: NEG32 sets true ----
    TEST_CASE t63_name
    mov eax, 5
    neg eax                ; -5 -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 64: NEG32 setc true ----
    TEST_CASE t64_name
    mov eax, 5
    neg eax                ; non-zero -> CF=1
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 65: NEG32 setc false ----
    TEST_CASE t65_name
    xor eax, eax
    neg eax                ; zero -> CF=0
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ================================================================
    ; INC/DEC producer + SETcc
    ; ================================================================

    ; ---- Test 66: INC32 sete true ----
    TEST_CASE t66_name
    mov eax, -1
    inc eax                ; 0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 67: INC32 sete false ----
    TEST_CASE t67_name
    mov eax, 5
    inc eax                ; 6 -> ZF=0
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 0

    ; ---- Test 68: INC32 sets true ----
    TEST_CASE t68_name
    mov eax, 0x7FFFFFFF
    inc eax                ; wraps to 0x80000000 -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 69: DEC32 sete true ----
    TEST_CASE t69_name
    mov eax, 1
    dec eax                ; 0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 70: DEC32 sets true ----
    TEST_CASE t70_name
    mov eax, 0
    dec eax                ; -1 -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 71: DEC32 seto true (INT_MIN - 1) ----
    TEST_CASE t71_name
    mov eax, 0x80000000
    dec eax                ; INT_MIN - 1 -> OF=1
    seto cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; 8/16-bit width tests
    ; ================================================================

    ; ---- Test 72: CMP8 sete true ----
    TEST_CASE t72_name
    mov al, 42
    cmp al, 42             ; ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 73: CMP16 sets true ----
    TEST_CASE t73_name
    mov ax, 5
    cmp ax, 100            ; 5-100 negative in 16-bit -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 74: TEST8 sete true ----
    TEST_CASE t74_name
    mov al, 0xF0
    test al, 0x0F          ; AND=0 -> ZF=1
    sete cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 75: AND8 sets true ----
    TEST_CASE t75_name
    mov al, 0x80
    and al, 0xFF           ; bit 7 set -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 76: ADD8 setc true ----
    TEST_CASE t76_name
    mov al, 0xFF
    add al, 1              ; 8-bit wrap -> CF=1
    setc cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    ; ---- Test 77: SUB16 sets true ----
    TEST_CASE t77_name
    mov ax, 5
    sub ax, 100            ; negative in 16-bit -> SF=1
    sets cl
    movzx ecx, cl
    CHECK_EQ_32 ecx, 1

    END_TESTS
