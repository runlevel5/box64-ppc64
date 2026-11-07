; test_cmovcc_fusion.asm - Test CMOVcc immediately after flag producers
; Tests in-block fusion: producer -> CMOVcc (no intervening call/barrier)
;
; Producers tested: CMP, TEST, AND, OR, XOR, ADD, SUB, NEG, INC, DEC
; Conditions tested: cmove/cmovne, cmovs/cmovns, cmovc/cmovnc, cmovo/cmovno,
;                    cmovl/cmovge, cmovle/cmovg, cmovb/cmova, cmovbe/cmovnbe
; Both taken and not-taken for each, 32-bit and 64-bit
;
; This exercises the dynarec's NATIVEMV optimization path

%include "test_framework.inc"

section .data
    ; ---- CMP producers (32-bit) ----
    t01_name: db "CMP32 cmove taken", 0
    t02_name: db "CMP32 cmove not-taken", 0
    t03_name: db "CMP32 cmovne taken", 0
    t04_name: db "CMP32 cmovne not-taken", 0
    t05_name: db "CMP32 cmovs taken", 0
    t06_name: db "CMP32 cmovs not-taken", 0
    t07_name: db "CMP32 cmovns taken", 0
    t08_name: db "CMP32 cmovc taken", 0
    t09_name: db "CMP32 cmovc not-taken", 0
    t10_name: db "CMP32 cmovnc taken", 0
    t11_name: db "CMP32 cmovo taken", 0
    t12_name: db "CMP32 cmovo not-taken", 0
    t13_name: db "CMP32 cmovno taken", 0
    t14_name: db "CMP32 cmovl taken", 0
    t15_name: db "CMP32 cmovl not-taken", 0
    t16_name: db "CMP32 cmovge taken", 0
    t17_name: db "CMP32 cmovle taken", 0
    t18_name: db "CMP32 cmovle not-taken", 0
    t19_name: db "CMP32 cmovg taken", 0
    t20_name: db "CMP32 cmovg not-taken", 0
    t21_name: db "CMP32 cmovbe taken", 0
    t22_name: db "CMP32 cmovbe not-taken", 0
    t23_name: db "CMP32 cmova taken", 0
    t24_name: db "CMP32 cmova not-taken", 0
    ; ---- CMP 64-bit ----
    t25_name: db "CMP64 cmove taken", 0
    t26_name: db "CMP64 cmove not-taken", 0
    t27_name: db "CMP64 cmovs taken", 0
    t28_name: db "CMP64 cmovl taken", 0
    ; ---- TEST producers ----
    t29_name: db "TEST32 cmove taken", 0
    t30_name: db "TEST32 cmove not-taken", 0
    t31_name: db "TEST32 cmovs taken", 0
    t32_name: db "TEST32 cmovs not-taken", 0
    t33_name: db "TEST64 cmove taken", 0
    t34_name: db "TEST64 cmovs taken", 0
    ; ---- AND producers ----
    t35_name: db "AND32 cmove taken", 0
    t36_name: db "AND32 cmove not-taken", 0
    t37_name: db "AND32 cmovs taken", 0
    t38_name: db "AND32 cmovs not-taken", 0
    ; ---- OR producers ----
    t39_name: db "OR32 cmove taken", 0
    t40_name: db "OR32 cmovs taken", 0
    ; ---- XOR producers ----
    t41_name: db "XOR32 cmove taken", 0
    t42_name: db "XOR32 cmovs taken", 0
    ; ---- ADD producers ----
    t43_name: db "ADD32 cmove taken", 0
    t44_name: db "ADD32 cmove not-taken", 0
    t45_name: db "ADD32 cmovs taken", 0
    t46_name: db "ADD32 cmovc taken", 0
    t47_name: db "ADD32 cmovo taken", 0
    ; ---- SUB producers ----
    t48_name: db "SUB32 cmove taken", 0
    t49_name: db "SUB32 cmovs taken", 0
    t50_name: db "SUB32 cmovc taken", 0
    t51_name: db "SUB32 cmovo taken", 0
    t52_name: db "SUB32 cmovl taken", 0
    ; ---- NEG producers ----
    t53_name: db "NEG32 cmove taken", 0
    t54_name: db "NEG32 cmovs taken", 0
    t55_name: db "NEG32 cmovc taken", 0
    ; ---- INC/DEC producers ----
    t56_name: db "INC32 cmove taken", 0
    t57_name: db "INC32 cmovs taken", 0
    t58_name: db "DEC32 cmove taken", 0
    t59_name: db "DEC32 cmovs taken", 0
    t60_name: db "DEC32 cmovo taken", 0
    ; ---- 64-bit CMOVcc result width ----
    t61_name: db "CMP64 cmove64 taken", 0
    t62_name: db "CMP64 cmovne64 taken", 0
    t63_name: db "ADD64 cmovs64 taken", 0
    t64_name: db "SUB64 cmovc64 taken", 0

section .text
global _start

_start:
    INIT_TESTS

    ; ================================================================
    ; CMP producer + CMOVcc (32-bit)
    ; ================================================================

    ; ---- Test 01: CMP32 cmove taken ----
    TEST_CASE t01_name
    mov eax, 42
    mov ecx, 99
    mov edx, 0
    cmp eax, 42            ; ZF=1
    cmove edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 02: CMP32 cmove not-taken ----
    TEST_CASE t02_name
    mov eax, 42
    mov ecx, 99
    mov edx, 55
    cmp eax, 43            ; ZF=0
    cmove edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 03: CMP32 cmovne taken ----
    TEST_CASE t03_name
    mov eax, 42
    mov ecx, 99
    mov edx, 0
    cmp eax, 43            ; ZF=0
    cmovne edx, ecx        ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 04: CMP32 cmovne not-taken ----
    TEST_CASE t04_name
    mov eax, 42
    mov ecx, 99
    mov edx, 55
    cmp eax, 42            ; ZF=1
    cmovne edx, ecx        ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 05: CMP32 cmovs taken ----
    TEST_CASE t05_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    cmp eax, 100           ; SF=1
    cmovs edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 06: CMP32 cmovs not-taken ----
    TEST_CASE t06_name
    mov eax, 100
    mov ecx, 99
    mov edx, 55
    cmp eax, 5             ; SF=0
    cmovs edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 07: CMP32 cmovns taken ----
    TEST_CASE t07_name
    mov eax, 100
    mov ecx, 99
    mov edx, 0
    cmp eax, 5             ; SF=0
    cmovns edx, ecx        ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 08: CMP32 cmovc taken ----
    TEST_CASE t08_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    cmp eax, 100           ; CF=1
    cmovc edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 09: CMP32 cmovc not-taken ----
    TEST_CASE t09_name
    mov eax, 100
    mov ecx, 99
    mov edx, 55
    cmp eax, 5             ; CF=0
    cmovc edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 10: CMP32 cmovnc taken ----
    TEST_CASE t10_name
    mov eax, 100
    mov ecx, 99
    mov edx, 0
    cmp eax, 5             ; CF=0
    cmovnc edx, ecx        ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 11: CMP32 cmovo taken ----
    TEST_CASE t11_name
    mov eax, 0x80000000
    mov ecx, 99
    mov edx, 0
    cmp eax, 1             ; OF=1
    cmovo edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 12: CMP32 cmovo not-taken ----
    TEST_CASE t12_name
    mov eax, 42
    mov ecx, 99
    mov edx, 55
    cmp eax, 10            ; OF=0
    cmovo edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 13: CMP32 cmovno taken ----
    TEST_CASE t13_name
    mov eax, 42
    mov ecx, 99
    mov edx, 0
    cmp eax, 10            ; OF=0
    cmovno edx, ecx        ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 14: CMP32 cmovl taken ----
    TEST_CASE t14_name
    mov eax, -5
    mov ecx, 99
    mov edx, 0
    cmp eax, 3             ; -5 < 3
    cmovl edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 15: CMP32 cmovl not-taken ----
    TEST_CASE t15_name
    mov eax, 10
    mov ecx, 99
    mov edx, 55
    cmp eax, 3             ; 10 >= 3
    cmovl edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 16: CMP32 cmovge taken ----
    TEST_CASE t16_name
    mov eax, 10
    mov ecx, 99
    mov edx, 0
    cmp eax, 3             ; 10 >= 3
    cmovge edx, ecx        ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 17: CMP32 cmovle taken ----
    TEST_CASE t17_name
    mov eax, 3
    mov ecx, 99
    mov edx, 0
    cmp eax, 3             ; equal -> ZF=1
    cmovle edx, ecx        ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 18: CMP32 cmovle not-taken ----
    TEST_CASE t18_name
    mov eax, 10
    mov ecx, 99
    mov edx, 55
    cmp eax, 3             ; 10 > 3
    cmovle edx, ecx        ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 19: CMP32 cmovg taken ----
    TEST_CASE t19_name
    mov eax, 10
    mov ecx, 99
    mov edx, 0
    cmp eax, 3             ; 10 > 3
    cmovg edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 20: CMP32 cmovg not-taken ----
    TEST_CASE t20_name
    mov eax, 3
    mov ecx, 99
    mov edx, 55
    cmp eax, 3             ; equal
    cmovg edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 21: CMP32 cmovbe taken ----
    TEST_CASE t21_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    cmp eax, 5             ; equal -> ZF=1
    cmovbe edx, ecx        ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 22: CMP32 cmovbe not-taken ----
    TEST_CASE t22_name
    mov eax, 100
    mov ecx, 99
    mov edx, 55
    cmp eax, 5             ; above -> CF=0 ZF=0
    cmovbe edx, ecx        ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 23: CMP32 cmova taken ----
    TEST_CASE t23_name
    mov eax, 100
    mov ecx, 99
    mov edx, 0
    cmp eax, 5             ; above
    cmova edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 24: CMP32 cmova not-taken ----
    TEST_CASE t24_name
    mov eax, 5
    mov ecx, 99
    mov edx, 55
    cmp eax, 5             ; equal -> ZF=1
    cmova edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ================================================================
    ; CMP 64-bit producer + CMOVcc
    ; ================================================================

    ; ---- Test 25: CMP64 cmove taken ----
    TEST_CASE t25_name
    mov rax, 0x100000000
    mov rbx, 0x100000000
    mov ecx, 99
    mov edx, 0
    cmp rax, rbx           ; ZF=1
    cmove edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 26: CMP64 cmove not-taken ----
    TEST_CASE t26_name
    mov rax, 0x100000000
    mov rbx, 0x100000001
    mov ecx, 99
    mov edx, 55
    cmp rax, rbx           ; ZF=0
    cmove edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 27: CMP64 cmovs taken ----
    TEST_CASE t27_name
    mov rax, 5
    mov rbx, 0x7FFFFFFFFFFFFFFF
    mov ecx, 99
    mov edx, 0
    cmp rax, rbx           ; negative -> SF=1
    cmovs edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 28: CMP64 cmovl taken ----
    TEST_CASE t28_name
    mov rax, -5
    mov rbx, 3
    mov ecx, 99
    mov edx, 0
    cmp rax, rbx           ; -5 < 3
    cmovl edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; TEST producer + CMOVcc
    ; ================================================================

    ; ---- Test 29: TEST32 cmove taken ----
    TEST_CASE t29_name
    mov eax, 0xFF00
    mov ecx, 99
    mov edx, 0
    test eax, 0x00FF       ; AND=0 -> ZF=1
    cmove edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 30: TEST32 cmove not-taken ----
    TEST_CASE t30_name
    mov eax, 0xFF
    mov ecx, 99
    mov edx, 55
    test eax, 0xFF         ; AND!=0 -> ZF=0
    cmove edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 31: TEST32 cmovs taken ----
    TEST_CASE t31_name
    mov eax, 0x80000000
    mov ecx, 99
    mov edx, 0
    test eax, eax          ; SF=1
    cmovs edx, ecx         ; taken -> edx=99
    CHECK_EQ_32 edx, 99

    ; ---- Test 32: TEST32 cmovs not-taken ----
    TEST_CASE t32_name
    mov eax, 0x7FFFFFFF
    mov ecx, 99
    mov edx, 55
    test eax, eax          ; SF=0
    cmovs edx, ecx         ; not taken -> edx=55
    CHECK_EQ_32 edx, 55

    ; ---- Test 33: TEST64 cmove taken ----
    TEST_CASE t33_name
    mov rax, 0xFF00000000
    mov rbx, 0x00FFFFFFFF
    mov ecx, 99
    mov edx, 0
    test rax, rbx          ; ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 34: TEST64 cmovs taken ----
    TEST_CASE t34_name
    mov rax, 0x8000000000000000
    mov ecx, 99
    mov edx, 0
    test rax, rax          ; SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; AND producer + CMOVcc
    ; ================================================================

    ; ---- Test 35: AND32 cmove taken ----
    TEST_CASE t35_name
    mov eax, 0xFF00
    mov ecx, 99
    mov edx, 0
    and eax, 0x00FF        ; result=0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 36: AND32 cmove not-taken ----
    TEST_CASE t36_name
    mov eax, 0xFFFF
    mov ecx, 99
    mov edx, 55
    and eax, 0x00FF        ; result=0xFF -> ZF=0
    cmove edx, ecx
    CHECK_EQ_32 edx, 55

    ; ---- Test 37: AND32 cmovs taken ----
    TEST_CASE t37_name
    mov eax, 0x80000000
    mov ebx, 0xF0000000
    mov ecx, 99
    mov edx, 0
    and eax, ebx           ; bit 31 set -> SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 38: AND32 cmovs not-taken ----
    TEST_CASE t38_name
    mov eax, 0x7FFFFFFF
    mov ebx, 0x0FFFFFFF
    mov ecx, 99
    mov edx, 55
    and eax, ebx           ; bit 31 clear -> SF=0
    cmovs edx, ecx
    CHECK_EQ_32 edx, 55

    ; ================================================================
    ; OR producer + CMOVcc
    ; ================================================================

    ; ---- Test 39: OR32 cmove taken ----
    TEST_CASE t39_name
    xor eax, eax
    mov ecx, 99
    mov edx, 0
    or eax, 0              ; 0|0=0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 40: OR32 cmovs taken ----
    TEST_CASE t40_name
    mov eax, 0x80000000
    mov ecx, 99
    mov edx, 0
    or eax, 0              ; SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; XOR producer + CMOVcc
    ; ================================================================

    ; ---- Test 41: XOR32 cmove taken ----
    TEST_CASE t41_name
    mov eax, 42
    mov ecx, 99
    mov edx, 0
    xor eax, eax           ; 0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 42: XOR32 cmovs taken ----
    TEST_CASE t42_name
    mov eax, 0x7FFFFFFF
    mov ebx, 0xFFFFFFFF
    mov ecx, 99
    mov edx, 0
    xor eax, ebx           ; 0x80000000 -> SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; ADD producer + CMOVcc
    ; ================================================================

    ; ---- Test 43: ADD32 cmove taken ----
    TEST_CASE t43_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    add eax, -5            ; 0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 44: ADD32 cmove not-taken ----
    TEST_CASE t44_name
    mov eax, 5
    mov ecx, 99
    mov edx, 55
    add eax, 1             ; 6 -> ZF=0
    cmove edx, ecx
    CHECK_EQ_32 edx, 55

    ; ---- Test 45: ADD32 cmovs taken ----
    TEST_CASE t45_name
    mov eax, 0x7FFFFFFF
    mov ecx, 99
    mov edx, 0
    add eax, 1             ; wraps -> SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 46: ADD32 cmovc taken ----
    TEST_CASE t46_name
    mov eax, 0xFFFFFFFF
    mov ecx, 99
    mov edx, 0
    add eax, 1             ; CF=1
    cmovc edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 47: ADD32 cmovo taken ----
    TEST_CASE t47_name
    mov eax, 0x7FFFFFFF
    mov ecx, 99
    mov edx, 0
    add eax, 1             ; OF=1
    cmovo edx, ecx
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; SUB producer + CMOVcc
    ; ================================================================

    ; ---- Test 48: SUB32 cmove taken ----
    TEST_CASE t48_name
    mov eax, 42
    mov ecx, 99
    mov edx, 0
    sub eax, 42            ; 0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 49: SUB32 cmovs taken ----
    TEST_CASE t49_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    sub eax, 10            ; -5 -> SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 50: SUB32 cmovc taken ----
    TEST_CASE t50_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    sub eax, 10            ; CF=1
    cmovc edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 51: SUB32 cmovo taken ----
    TEST_CASE t51_name
    mov eax, 0x80000000
    mov ecx, 99
    mov edx, 0
    sub eax, 1             ; OF=1
    cmovo edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 52: SUB32 cmovl taken ----
    TEST_CASE t52_name
    mov eax, -5
    mov ecx, 99
    mov edx, 0
    sub eax, 3             ; -8, SF=1 OF=0 -> cmovl taken
    cmovl edx, ecx
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; NEG producer + CMOVcc
    ; ================================================================

    ; ---- Test 53: NEG32 cmove taken ----
    TEST_CASE t53_name
    xor eax, eax
    mov ecx, 99
    mov edx, 0
    neg eax                ; 0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 54: NEG32 cmovs taken ----
    TEST_CASE t54_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    neg eax                ; -5 -> SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 55: NEG32 cmovc taken ----
    TEST_CASE t55_name
    mov eax, 5
    mov ecx, 99
    mov edx, 0
    neg eax                ; non-zero -> CF=1
    cmovc edx, ecx
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; INC/DEC producer + CMOVcc
    ; ================================================================

    ; ---- Test 56: INC32 cmove taken ----
    TEST_CASE t56_name
    mov eax, -1
    mov ecx, 99
    mov edx, 0
    inc eax                ; 0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 57: INC32 cmovs taken ----
    TEST_CASE t57_name
    mov eax, 0x7FFFFFFF
    mov ecx, 99
    mov edx, 0
    inc eax                ; wraps -> SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 58: DEC32 cmove taken ----
    TEST_CASE t58_name
    mov eax, 1
    mov ecx, 99
    mov edx, 0
    dec eax                ; 0 -> ZF=1
    cmove edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 59: DEC32 cmovs taken ----
    TEST_CASE t59_name
    mov eax, 0
    mov ecx, 99
    mov edx, 0
    dec eax                ; -1 -> SF=1
    cmovs edx, ecx
    CHECK_EQ_32 edx, 99

    ; ---- Test 60: DEC32 cmovo taken ----
    TEST_CASE t60_name
    mov eax, 0x80000000
    mov ecx, 99
    mov edx, 0
    dec eax                ; INT_MIN-1 -> OF=1
    cmovo edx, ecx
    CHECK_EQ_32 edx, 99

    ; ================================================================
    ; 64-bit CMOVcc result width tests
    ; ================================================================

    ; ---- Test 61: CMP64 cmove64 taken (64-bit dest) ----
    TEST_CASE t61_name
    mov rax, 0x100000000
    mov rbx, 0x100000000
    mov rcx, 0xDEADBEEF12345678
    xor rdx, rdx
    cmp rax, rbx           ; ZF=1
    cmove rdx, rcx         ; taken -> rdx=0xDEADBEEF12345678
    CHECK_EQ_64 rdx, 0xDEADBEEF12345678

    ; ---- Test 62: CMP64 cmovne64 taken (64-bit dest) ----
    TEST_CASE t62_name
    mov rax, 0x100000000
    mov rbx, 0x100000001
    mov rcx, 0xCAFEBABE00000000
    xor rdx, rdx
    cmp rax, rbx           ; ZF=0
    cmovne rdx, rcx        ; taken -> rdx=0xCAFEBABE00000000
    CHECK_EQ_64 rdx, 0xCAFEBABE00000000

    ; ---- Test 63: ADD64 cmovs64 taken (64-bit dest) ----
    TEST_CASE t63_name
    mov rax, 0x7FFFFFFFFFFFFFFF
    mov rcx, 0xABCDEF0123456789
    xor rdx, rdx
    add rax, 1             ; wraps -> SF=1
    cmovs rdx, rcx         ; taken
    CHECK_EQ_64 rdx, 0xABCDEF0123456789

    ; ---- Test 64: SUB64 cmovc64 taken (64-bit dest) ----
    TEST_CASE t64_name
    mov rax, 5
    mov rbx, 100
    mov rcx, 0x1234567890ABCDEF
    xor rdx, rdx
    sub rax, rbx           ; CF=1
    cmovc rdx, rcx         ; taken
    CHECK_EQ_64 rdx, 0x1234567890ABCDEF

    END_TESTS
