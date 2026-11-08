; test_jcc_fusion.asm - Test conditional jumps immediately after flag producers
; Tests in-block fusion: producer -> Jcc (no intervening call/barrier)
;
; Producers tested: CMP, TEST, AND, OR, XOR, ADD, SUB, NEG, INC, DEC
; Conditions tested: je/jne, js/jns, jc/jnc, jo/jno, jl/jge, jle/jg, jb/jae, jbe/ja
; Both taken and not-taken paths for each combination
;
; This exercises the dynarec's native flag fusion optimization path
; (NATIVEJUMP on PPC64LE, IFNATIVE on ARM64)

%include "test_framework.inc"

section .data
    ; ---- CMP producers ----
    t01_name: db "CMP32 je taken", 0
    t02_name: db "CMP32 je not-taken", 0
    t03_name: db "CMP32 jne taken", 0
    t04_name: db "CMP32 js taken", 0
    t05_name: db "CMP32 js not-taken", 0
    t06_name: db "CMP32 jns taken", 0
    t07_name: db "CMP32 jc taken", 0
    t08_name: db "CMP32 jc not-taken", 0
    t09_name: db "CMP32 jnc taken", 0
    t10_name: db "CMP32 jo taken", 0
    t11_name: db "CMP32 jo not-taken", 0
    t12_name: db "CMP32 jno taken", 0
    t13_name: db "CMP32 jl taken", 0
    t14_name: db "CMP32 jl not-taken", 0
    t15_name: db "CMP32 jge taken", 0
    t16_name: db "CMP32 jle taken", 0
    t17_name: db "CMP32 jg taken", 0
    t18_name: db "CMP64 je taken", 0
    t19_name: db "CMP64 js taken", 0
    t20_name: db "CMP64 jl taken", 0
    ; ---- TEST producers ----
    t21_name: db "TEST32 je taken", 0
    t22_name: db "TEST32 je not-taken", 0
    t23_name: db "TEST32 js taken", 0
    t24_name: db "TEST32 js not-taken", 0
    t25_name: db "TEST32 jne taken", 0
    t26_name: db "TEST64 je taken", 0
    t27_name: db "TEST64 js taken", 0
    ; ---- AND producers ----
    t28_name: db "AND32 je taken", 0
    t29_name: db "AND32 je not-taken", 0
    t30_name: db "AND32 js taken", 0
    t31_name: db "AND32 js not-taken", 0
    t32_name: db "AND32 jne taken", 0
    t33_name: db "AND64 je taken", 0
    t34_name: db "AND64 js taken", 0
    ; ---- OR producers ----
    t35_name: db "OR32 je taken", 0
    t36_name: db "OR32 je not-taken", 0
    t37_name: db "OR32 js taken", 0
    t38_name: db "OR32 jne taken", 0
    t39_name: db "OR64 js taken", 0
    ; ---- XOR producers ----
    t40_name: db "XOR32 je taken", 0
    t41_name: db "XOR32 je not-taken", 0
    t42_name: db "XOR32 js taken", 0
    t43_name: db "XOR32 jne taken", 0
    t44_name: db "XOR64 je taken", 0
    ; ---- ADD producers ----
    t45_name: db "ADD32 je taken", 0
    t46_name: db "ADD32 je not-taken", 0
    t47_name: db "ADD32 js taken", 0
    t48_name: db "ADD32 js not-taken", 0
    t49_name: db "ADD32 jc taken", 0
    t50_name: db "ADD32 jc not-taken", 0
    t51_name: db "ADD32 jo taken", 0
    t52_name: db "ADD32 jo not-taken", 0
    t53_name: db "ADD32 jl taken", 0
    t54_name: db "ADD64 je taken", 0
    t55_name: db "ADD64 js taken", 0
    t56_name: db "ADD64 jc taken", 0
    ; ---- SUB producers ----
    t57_name: db "SUB32 je taken", 0
    t58_name: db "SUB32 je not-taken", 0
    t59_name: db "SUB32 js taken", 0
    t60_name: db "SUB32 jc taken", 0
    t61_name: db "SUB32 jo taken", 0
    t62_name: db "SUB32 jl taken", 0
    t63_name: db "SUB64 je taken", 0
    t64_name: db "SUB64 js taken", 0
    ; ---- NEG producer ----
    t65_name: db "NEG32 je taken", 0
    t66_name: db "NEG32 je not-taken", 0
    t67_name: db "NEG32 js taken", 0
    t68_name: db "NEG32 js not-taken", 0
    t69_name: db "NEG32 jc taken", 0
    t70_name: db "NEG32 jc not-taken", 0
    t71_name: db "NEG64 js taken", 0
    ; ---- INC/DEC producers ----
    t72_name: db "INC32 je taken", 0
    t73_name: db "INC32 je not-taken", 0
    t74_name: db "INC32 js taken", 0
    t75_name: db "DEC32 je taken", 0
    t76_name: db "DEC32 je not-taken", 0
    t77_name: db "DEC32 js taken", 0
    t78_name: db "DEC32 jo taken", 0
    ; ---- 8/16-bit width tests ----
    t79_name: db "CMP8 je taken", 0
    t80_name: db "CMP8 js taken", 0
    t81_name: db "CMP16 je taken", 0
    t82_name: db "TEST8 je taken", 0
    t83_name: db "AND8 js taken", 0
    t84_name: db "ADD8 jc taken", 0
    t85_name: db "SUB16 js taken", 0
    ; ---- Multi-condition sequences ----
    t86_name: db "CMP32 jbe taken", 0
    t87_name: db "CMP32 jbe not-taken", 0
    t88_name: db "CMP32 ja taken", 0
    t89_name: db "CMP32 ja not-taken", 0

section .text
global _start

_start:
    INIT_TESTS

    ; ================================================================
    ; CMP producer tests
    ; ================================================================

    ; ---- Test 01: CMP32 je taken (equal) ----
    TEST_CASE t01_name
    mov eax, 42
    mov ecx, 0
    cmp eax, 42            ; ZF=1
    je .t01_taken
    mov ecx, 0             ; not taken path
    jmp .t01_check
.t01_taken:
    mov ecx, 1
.t01_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 02: CMP32 je not-taken ----
    TEST_CASE t02_name
    mov eax, 42
    mov ecx, 0
    cmp eax, 43            ; ZF=0
    je .t02_taken
    mov ecx, 1             ; not taken -> correct
    jmp .t02_check
.t02_taken:
    mov ecx, 0
.t02_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 03: CMP32 jne taken ----
    TEST_CASE t03_name
    mov eax, 42
    mov ecx, 0
    cmp eax, 43            ; ZF=0
    jne .t03_taken
    jmp .t03_check
.t03_taken:
    mov ecx, 1
.t03_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 04: CMP32 js taken (result negative) ----
    TEST_CASE t04_name
    mov eax, 5
    mov ecx, 0
    cmp eax, 100           ; 5-100 = negative -> SF=1
    js .t04_taken
    jmp .t04_check
.t04_taken:
    mov ecx, 1
.t04_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 05: CMP32 js not-taken ----
    TEST_CASE t05_name
    mov eax, 100
    mov ecx, 0
    cmp eax, 5             ; 100-5 = positive -> SF=0
    js .t05_taken
    mov ecx, 1
    jmp .t05_check
.t05_taken:
    mov ecx, 0
.t05_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 06: CMP32 jns taken ----
    TEST_CASE t06_name
    mov eax, 100
    mov ecx, 0
    cmp eax, 5             ; positive -> SF=0
    jns .t06_taken
    jmp .t06_check
.t06_taken:
    mov ecx, 1
.t06_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 07: CMP32 jc taken (borrow) ----
    TEST_CASE t07_name
    mov eax, 5
    mov ecx, 0
    cmp eax, 100           ; 5 < 100 unsigned -> CF=1
    jc .t07_taken
    jmp .t07_check
.t07_taken:
    mov ecx, 1
.t07_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 08: CMP32 jc not-taken ----
    TEST_CASE t08_name
    mov eax, 100
    mov ecx, 0
    cmp eax, 5             ; 100 >= 5 unsigned -> CF=0
    jc .t08_taken
    mov ecx, 1
    jmp .t08_check
.t08_taken:
    mov ecx, 0
.t08_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 09: CMP32 jnc taken ----
    TEST_CASE t09_name
    mov eax, 100
    mov ecx, 0
    cmp eax, 5             ; CF=0
    jnc .t09_taken
    jmp .t09_check
.t09_taken:
    mov ecx, 1
.t09_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 10: CMP32 jo taken (overflow) ----
    TEST_CASE t10_name
    mov eax, 0x80000000    ; INT32_MIN
    mov ecx, 0
    cmp eax, 1             ; INT32_MIN - 1 overflows -> OF=1
    jo .t10_taken
    jmp .t10_check
.t10_taken:
    mov ecx, 1
.t10_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 11: CMP32 jo not-taken ----
    TEST_CASE t11_name
    mov eax, 42
    mov ecx, 0
    cmp eax, 10            ; no overflow -> OF=0
    jo .t11_taken
    mov ecx, 1
    jmp .t11_check
.t11_taken:
    mov ecx, 0
.t11_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 12: CMP32 jno taken ----
    TEST_CASE t12_name
    mov eax, 42
    mov ecx, 0
    cmp eax, 10            ; OF=0
    jno .t12_taken
    jmp .t12_check
.t12_taken:
    mov ecx, 1
.t12_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 13: CMP32 jl taken (signed less: SF!=OF) ----
    TEST_CASE t13_name
    mov eax, -5
    mov ecx, 0
    cmp eax, 3             ; -5 < 3 signed
    jl .t13_taken
    jmp .t13_check
.t13_taken:
    mov ecx, 1
.t13_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 14: CMP32 jl not-taken ----
    TEST_CASE t14_name
    mov eax, 10
    mov ecx, 0
    cmp eax, 3             ; 10 >= 3
    jl .t14_taken
    mov ecx, 1
    jmp .t14_check
.t14_taken:
    mov ecx, 0
.t14_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 15: CMP32 jge taken (signed greater-or-equal) ----
    TEST_CASE t15_name
    mov eax, 10
    mov ecx, 0
    cmp eax, 3             ; 10 >= 3
    jge .t15_taken
    jmp .t15_check
.t15_taken:
    mov ecx, 1
.t15_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 16: CMP32 jle taken (signed less-or-equal: ZF=1 or SF!=OF) ----
    TEST_CASE t16_name
    mov eax, 3
    mov ecx, 0
    cmp eax, 3             ; equal -> ZF=1 -> jle taken
    jle .t16_taken
    jmp .t16_check
.t16_taken:
    mov ecx, 1
.t16_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 17: CMP32 jg taken (signed greater: ZF=0 and SF=OF) ----
    TEST_CASE t17_name
    mov eax, 10
    mov ecx, 0
    cmp eax, 3             ; 10 > 3
    jg .t17_taken
    jmp .t17_check
.t17_taken:
    mov ecx, 1
.t17_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 18: CMP64 je taken ----
    TEST_CASE t18_name
    mov rax, 0x100000000
    mov rbx, 0x100000000
    mov ecx, 0
    cmp rax, rbx           ; equal -> ZF=1
    je .t18_taken
    jmp .t18_check
.t18_taken:
    mov ecx, 1
.t18_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 19: CMP64 js taken ----
    TEST_CASE t19_name
    mov rax, 5
    mov rbx, 0x7FFFFFFFFFFFFFFF
    mov ecx, 0
    cmp rax, rbx           ; 5 - MAX_INT64 -> negative
    js .t19_taken
    jmp .t19_check
.t19_taken:
    mov ecx, 1
.t19_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 20: CMP64 jl taken ----
    TEST_CASE t20_name
    mov rax, -5
    mov rbx, 3
    mov ecx, 0
    cmp rax, rbx           ; -5 < 3
    jl .t20_taken
    jmp .t20_check
.t20_taken:
    mov ecx, 1
.t20_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; TEST producer tests
    ; ================================================================

    ; ---- Test 21: TEST32 je taken (zero result) ----
    TEST_CASE t21_name
    mov eax, 0xFF00
    mov ecx, 0
    test eax, 0x00FF       ; AND result = 0 -> ZF=1
    je .t21_taken
    jmp .t21_check
.t21_taken:
    mov ecx, 1
.t21_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 22: TEST32 je not-taken ----
    TEST_CASE t22_name
    mov eax, 0xFF
    mov ecx, 0
    test eax, 0xFF         ; AND result != 0 -> ZF=0
    je .t22_taken
    mov ecx, 1
    jmp .t22_check
.t22_taken:
    mov ecx, 0
.t22_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 23: TEST32 js taken ----
    TEST_CASE t23_name
    mov eax, 0x80000000
    mov ecx, 0
    test eax, eax          ; bit 31 set -> SF=1
    js .t23_taken
    jmp .t23_check
.t23_taken:
    mov ecx, 1
.t23_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 24: TEST32 js not-taken ----
    TEST_CASE t24_name
    mov eax, 0x7FFFFFFF
    mov ecx, 0
    test eax, eax          ; bit 31 clear -> SF=0
    js .t24_taken
    mov ecx, 1
    jmp .t24_check
.t24_taken:
    mov ecx, 0
.t24_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 25: TEST32 jne taken ----
    TEST_CASE t25_name
    mov eax, 0x42
    mov ecx, 0
    test eax, eax          ; non-zero -> ZF=0
    jne .t25_taken
    jmp .t25_check
.t25_taken:
    mov ecx, 1
.t25_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 26: TEST64 je taken ----
    TEST_CASE t26_name
    mov rax, 0xFF00000000
    mov rbx, 0x00FFFFFFFF
    mov ecx, 0
    test rax, rbx          ; no overlapping bits -> ZF=1
    je .t26_taken
    jmp .t26_check
.t26_taken:
    mov ecx, 1
.t26_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 27: TEST64 js taken ----
    TEST_CASE t27_name
    mov rax, 0x8000000000000000
    mov ecx, 0
    test rax, rax          ; bit 63 set -> SF=1
    js .t27_taken
    jmp .t27_check
.t27_taken:
    mov ecx, 1
.t27_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; AND producer tests
    ; ================================================================

    ; ---- Test 28: AND32 je taken ----
    TEST_CASE t28_name
    mov eax, 0xFF00
    mov ecx, 0
    and eax, 0x00FF        ; result=0 -> ZF=1
    je .t28_taken
    jmp .t28_check
.t28_taken:
    mov ecx, 1
.t28_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 29: AND32 je not-taken ----
    TEST_CASE t29_name
    mov eax, 0xFFFF
    mov ecx, 0
    and eax, 0x00FF        ; result=0xFF -> ZF=0
    je .t29_taken
    mov ecx, 1
    jmp .t29_check
.t29_taken:
    mov ecx, 0
.t29_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 30: AND32 js taken ----
    TEST_CASE t30_name
    mov eax, 0x80000000
    mov ebx, 0xF0000000
    mov ecx, 0
    and eax, ebx           ; result has bit 31 set -> SF=1
    js .t30_taken
    jmp .t30_check
.t30_taken:
    mov ecx, 1
.t30_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 31: AND32 js not-taken ----
    TEST_CASE t31_name
    mov eax, 0x7FFFFFFF
    mov ebx, 0x0FFFFFFF
    mov ecx, 0
    and eax, ebx           ; result bit 31 clear -> SF=0
    js .t31_taken
    mov ecx, 1
    jmp .t31_check
.t31_taken:
    mov ecx, 0
.t31_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 32: AND32 jne taken ----
    TEST_CASE t32_name
    mov eax, 0xFFFF
    mov ecx, 0
    and eax, 0x00FF        ; result=0xFF -> ZF=0
    jne .t32_taken
    jmp .t32_check
.t32_taken:
    mov ecx, 1
.t32_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 33: AND64 je taken ----
    TEST_CASE t33_name
    mov rax, 0xFF00000000
    mov rbx, 0x00FFFFFFFF
    mov ecx, 0
    and rax, rbx           ; no overlap -> ZF=1
    je .t33_taken
    jmp .t33_check
.t33_taken:
    mov ecx, 1
.t33_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 34: AND64 js taken ----
    TEST_CASE t34_name
    mov rax, 0x8000000000000000
    mov rbx, 0xF000000000000000
    mov ecx, 0
    and rax, rbx           ; bit 63 set -> SF=1
    js .t34_taken
    jmp .t34_check
.t34_taken:
    mov ecx, 1
.t34_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; OR producer tests
    ; ================================================================

    ; ---- Test 35: OR32 je taken ----
    TEST_CASE t35_name
    xor eax, eax
    mov ecx, 0
    or eax, 0              ; 0|0=0 -> ZF=1
    je .t35_taken
    jmp .t35_check
.t35_taken:
    mov ecx, 1
.t35_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 36: OR32 je not-taken ----
    TEST_CASE t36_name
    mov eax, 1
    mov ecx, 0
    or eax, 0              ; 1|0=1 -> ZF=0
    je .t36_taken
    mov ecx, 1
    jmp .t36_check
.t36_taken:
    mov ecx, 0
.t36_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 37: OR32 js taken ----
    TEST_CASE t37_name
    mov eax, 0x80000000
    mov ecx, 0
    or eax, 0              ; bit 31 set -> SF=1
    js .t37_taken
    jmp .t37_check
.t37_taken:
    mov ecx, 1
.t37_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 38: OR32 jne taken ----
    TEST_CASE t38_name
    mov eax, 0
    mov ecx, 0
    or eax, 1              ; result=1 -> ZF=0
    jne .t38_taken
    jmp .t38_check
.t38_taken:
    mov ecx, 1
.t38_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 39: OR64 js taken ----
    TEST_CASE t39_name
    mov rax, 0x8000000000000000
    mov ecx, 0
    or rax, 0              ; bit 63 set -> SF=1
    js .t39_taken
    jmp .t39_check
.t39_taken:
    mov ecx, 1
.t39_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; XOR producer tests
    ; ================================================================

    ; ---- Test 40: XOR32 je taken (self-xor = 0) ----
    TEST_CASE t40_name
    mov eax, 42
    mov ecx, 0
    xor eax, eax           ; result=0 -> ZF=1
    je .t40_taken
    jmp .t40_check
.t40_taken:
    mov ecx, 1
.t40_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 41: XOR32 je not-taken ----
    TEST_CASE t41_name
    mov eax, 0xFF
    mov ecx, 0
    xor eax, 0x0F          ; result=0xF0 -> ZF=0
    je .t41_taken
    mov ecx, 1
    jmp .t41_check
.t41_taken:
    mov ecx, 0
.t41_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 42: XOR32 js taken ----
    TEST_CASE t42_name
    mov eax, 0x7FFFFFFF
    mov ebx, 0xFFFFFFFF
    mov ecx, 0
    xor eax, ebx           ; result=0x80000000 -> SF=1
    js .t42_taken
    jmp .t42_check
.t42_taken:
    mov ecx, 1
.t42_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 43: XOR32 jne taken ----
    TEST_CASE t43_name
    mov eax, 0xFF
    mov ecx, 0
    xor eax, 0x0F          ; result=0xF0 -> ZF=0
    jne .t43_taken
    jmp .t43_check
.t43_taken:
    mov ecx, 1
.t43_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 44: XOR64 je taken ----
    TEST_CASE t44_name
    mov rax, 0x123456789
    mov rbx, 0x123456789
    mov ecx, 0
    xor rax, rbx           ; result=0 -> ZF=1
    je .t44_taken
    jmp .t44_check
.t44_taken:
    mov ecx, 1
.t44_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; ADD producer tests
    ; ================================================================

    ; ---- Test 45: ADD32 je taken ----
    TEST_CASE t45_name
    mov eax, 5
    mov ecx, 0
    add eax, -5            ; 5+(-5)=0 -> ZF=1
    je .t45_taken
    jmp .t45_check
.t45_taken:
    mov ecx, 1
.t45_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 46: ADD32 je not-taken ----
    TEST_CASE t46_name
    mov eax, 5
    mov ecx, 0
    add eax, 1             ; result=6 -> ZF=0
    je .t46_taken
    mov ecx, 1
    jmp .t46_check
.t46_taken:
    mov ecx, 0
.t46_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 47: ADD32 js taken ----
    TEST_CASE t47_name
    mov eax, 0x7FFFFFFF
    mov ecx, 0
    add eax, 1             ; wraps to 0x80000000 -> SF=1
    js .t47_taken
    jmp .t47_check
.t47_taken:
    mov ecx, 1
.t47_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 48: ADD32 js not-taken ----
    TEST_CASE t48_name
    mov eax, 5
    mov ecx, 0
    add eax, 10            ; 15 -> SF=0
    js .t48_taken
    mov ecx, 1
    jmp .t48_check
.t48_taken:
    mov ecx, 0
.t48_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 49: ADD32 jc taken (unsigned overflow) ----
    TEST_CASE t49_name
    mov eax, 0xFFFFFFFF
    mov ecx, 0
    add eax, 1             ; wraps -> CF=1
    jc .t49_taken
    jmp .t49_check
.t49_taken:
    mov ecx, 1
.t49_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 50: ADD32 jc not-taken ----
    TEST_CASE t50_name
    mov eax, 5
    mov ecx, 0
    add eax, 10            ; no carry -> CF=0
    jc .t50_taken
    mov ecx, 1
    jmp .t50_check
.t50_taken:
    mov ecx, 0
.t50_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 51: ADD32 jo taken (signed overflow) ----
    TEST_CASE t51_name
    mov eax, 0x7FFFFFFF
    mov ecx, 0
    add eax, 1             ; INT_MAX + 1 -> OF=1
    jo .t51_taken
    jmp .t51_check
.t51_taken:
    mov ecx, 1
.t51_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 52: ADD32 jo not-taken ----
    TEST_CASE t52_name
    mov eax, 5
    mov ecx, 0
    add eax, 10            ; no overflow -> OF=0
    jo .t52_taken
    mov ecx, 1
    jmp .t52_check
.t52_taken:
    mov ecx, 0
.t52_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 53: ADD32 jl taken (signed less: result looks negative due to overflow) ----
    ; After ADD, jl checks SF!=OF. With overflow (0x7FFFFFFF+1): SF=1, OF=1 -> SF==OF -> jl NOT taken
    ; Use a simpler case: -5 + 1 = -4, SF=1 OF=0 -> SF!=OF -> jl taken
    ; But jl after ADD is unusual. Let's test: result=-4 -> use cmp-style check
    ; Actually jl means "result < 0 in signed comparison context" which for ADD means SF!=OF
    TEST_CASE t53_name
    mov eax, -10
    mov ebx, 3
    mov ecx, 0
    add eax, ebx           ; -10 + 3 = -7, SF=1, OF=0 -> jl taken (SF!=OF)
    jl .t53_taken
    jmp .t53_check
.t53_taken:
    mov ecx, 1
.t53_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 54: ADD64 je taken ----
    TEST_CASE t54_name
    mov rax, 0x100000000
    mov rbx, -0x100000000
    mov ecx, 0
    add rax, rbx           ; result=0 -> ZF=1
    je .t54_taken
    jmp .t54_check
.t54_taken:
    mov ecx, 1
.t54_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 55: ADD64 js taken ----
    TEST_CASE t55_name
    mov rax, 0x7FFFFFFFFFFFFFFF
    mov ecx, 0
    add rax, 1             ; wraps to 0x8000000000000000 -> SF=1
    js .t55_taken
    jmp .t55_check
.t55_taken:
    mov ecx, 1
.t55_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 56: ADD64 jc taken ----
    TEST_CASE t56_name
    mov rax, 0xFFFFFFFFFFFFFFFF
    mov ecx, 0
    add rax, 1             ; wraps -> CF=1
    jc .t56_taken
    jmp .t56_check
.t56_taken:
    mov ecx, 1
.t56_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; SUB producer tests
    ; ================================================================

    ; ---- Test 57: SUB32 je taken ----
    TEST_CASE t57_name
    mov eax, 42
    mov ecx, 0
    sub eax, 42            ; 0 -> ZF=1
    je .t57_taken
    jmp .t57_check
.t57_taken:
    mov ecx, 1
.t57_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 58: SUB32 je not-taken ----
    TEST_CASE t58_name
    mov eax, 42
    mov ecx, 0
    sub eax, 10            ; 32 -> ZF=0
    je .t58_taken
    mov ecx, 1
    jmp .t58_check
.t58_taken:
    mov ecx, 0
.t58_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 59: SUB32 js taken ----
    TEST_CASE t59_name
    mov eax, 5
    mov ecx, 0
    sub eax, 10            ; -5 -> SF=1
    js .t59_taken
    jmp .t59_check
.t59_taken:
    mov ecx, 1
.t59_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 60: SUB32 jc taken (borrow) ----
    TEST_CASE t60_name
    mov eax, 5
    mov ecx, 0
    sub eax, 10            ; 5 < 10 unsigned -> CF=1
    jc .t60_taken
    jmp .t60_check
.t60_taken:
    mov ecx, 1
.t60_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 61: SUB32 jo taken (signed overflow) ----
    TEST_CASE t61_name
    mov eax, 0x80000000    ; INT_MIN
    mov ecx, 0
    sub eax, 1             ; INT_MIN - 1 overflows -> OF=1
    jo .t61_taken
    jmp .t61_check
.t61_taken:
    mov ecx, 1
.t61_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 62: SUB32 jl taken ----
    TEST_CASE t62_name
    mov eax, -5
    mov ecx, 0
    sub eax, 3             ; -5 - 3 = -8 -> SF=1, OF=0 -> jl taken
    jl .t62_taken
    jmp .t62_check
.t62_taken:
    mov ecx, 1
.t62_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 63: SUB64 je taken ----
    TEST_CASE t63_name
    mov rax, 0x100000000
    mov rbx, 0x100000000
    mov ecx, 0
    sub rax, rbx           ; 0 -> ZF=1
    je .t63_taken
    jmp .t63_check
.t63_taken:
    mov ecx, 1
.t63_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 64: SUB64 js taken ----
    TEST_CASE t64_name
    mov rax, 5
    mov rbx, 100
    mov ecx, 0
    sub rax, rbx           ; negative -> SF=1
    js .t64_taken
    jmp .t64_check
.t64_taken:
    mov ecx, 1
.t64_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; NEG producer tests
    ; ================================================================

    ; ---- Test 65: NEG32 je taken ----
    TEST_CASE t65_name
    xor eax, eax
    mov ecx, 0
    neg eax                ; neg(0) = 0 -> ZF=1, CF=0
    je .t65_taken
    jmp .t65_check
.t65_taken:
    mov ecx, 1
.t65_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 66: NEG32 je not-taken ----
    TEST_CASE t66_name
    mov eax, 5
    mov ecx, 0
    neg eax                ; -5 -> ZF=0
    je .t66_taken
    mov ecx, 1
    jmp .t66_check
.t66_taken:
    mov ecx, 0
.t66_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 67: NEG32 js taken ----
    TEST_CASE t67_name
    mov eax, 5
    mov ecx, 0
    neg eax                ; -5 -> SF=1
    js .t67_taken
    jmp .t67_check
.t67_taken:
    mov ecx, 1
.t67_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 68: NEG32 js not-taken ----
    TEST_CASE t68_name
    mov eax, -5
    mov ecx, 0
    neg eax                ; 5 -> SF=0
    js .t68_taken
    mov ecx, 1
    jmp .t68_check
.t68_taken:
    mov ecx, 0
.t68_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 69: NEG32 jc taken (non-zero operand -> CF=1) ----
    TEST_CASE t69_name
    mov eax, 5
    mov ecx, 0
    neg eax                ; neg(non-zero) -> CF=1
    jc .t69_taken
    jmp .t69_check
.t69_taken:
    mov ecx, 1
.t69_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 70: NEG32 jc not-taken (zero operand -> CF=0) ----
    TEST_CASE t70_name
    xor eax, eax
    mov ecx, 0
    neg eax                ; neg(0) -> CF=0
    jc .t70_taken
    mov ecx, 1
    jmp .t70_check
.t70_taken:
    mov ecx, 0
.t70_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 71: NEG64 js taken ----
    TEST_CASE t71_name
    mov rax, 0x100000000
    mov ecx, 0
    neg rax                ; large negative -> SF=1
    js .t71_taken
    jmp .t71_check
.t71_taken:
    mov ecx, 1
.t71_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; INC/DEC producer tests
    ; ================================================================

    ; ---- Test 72: INC32 je taken (wraps -1 -> 0) ----
    TEST_CASE t72_name
    mov eax, -1
    mov ecx, 0
    inc eax                ; -1+1 = 0 -> ZF=1
    je .t72_taken
    jmp .t72_check
.t72_taken:
    mov ecx, 1
.t72_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 73: INC32 je not-taken ----
    TEST_CASE t73_name
    mov eax, 5
    mov ecx, 0
    inc eax                ; 6 -> ZF=0
    je .t73_taken
    mov ecx, 1
    jmp .t73_check
.t73_taken:
    mov ecx, 0
.t73_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 74: INC32 js taken ----
    TEST_CASE t74_name
    mov eax, 0x7FFFFFFF
    mov ecx, 0
    inc eax                ; wraps to 0x80000000 -> SF=1
    js .t74_taken
    jmp .t74_check
.t74_taken:
    mov ecx, 1
.t74_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 75: DEC32 je taken ----
    TEST_CASE t75_name
    mov eax, 1
    mov ecx, 0
    dec eax                ; 0 -> ZF=1
    je .t75_taken
    jmp .t75_check
.t75_taken:
    mov ecx, 1
.t75_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 76: DEC32 je not-taken ----
    TEST_CASE t76_name
    mov eax, 5
    mov ecx, 0
    dec eax                ; 4 -> ZF=0
    je .t76_taken
    mov ecx, 1
    jmp .t76_check
.t76_taken:
    mov ecx, 0
.t76_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 77: DEC32 js taken ----
    TEST_CASE t77_name
    mov eax, 0
    mov ecx, 0
    dec eax                ; -1 -> SF=1
    js .t77_taken
    jmp .t77_check
.t77_taken:
    mov ecx, 1
.t77_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 78: DEC32 jo taken (signed overflow: INT_MIN - 1) ----
    TEST_CASE t78_name
    mov eax, 0x80000000    ; INT_MIN
    mov ecx, 0
    dec eax                ; INT_MIN - 1 overflows -> OF=1
    jo .t78_taken
    jmp .t78_check
.t78_taken:
    mov ecx, 1
.t78_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; 8/16-bit width tests
    ; ================================================================

    ; ---- Test 79: CMP8 je taken ----
    TEST_CASE t79_name
    mov al, 42
    mov ecx, 0
    cmp al, 42             ; ZF=1
    je .t79_taken
    jmp .t79_check
.t79_taken:
    mov ecx, 1
.t79_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 80: CMP8 js taken ----
    TEST_CASE t80_name
    mov al, 5
    mov ecx, 0
    cmp al, 100            ; 5-100 wraps in 8-bit -> SF=1
    js .t80_taken
    jmp .t80_check
.t80_taken:
    mov ecx, 1
.t80_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 81: CMP16 je taken ----
    TEST_CASE t81_name
    mov ax, 1000
    mov ecx, 0
    cmp ax, 1000           ; ZF=1
    je .t81_taken
    jmp .t81_check
.t81_taken:
    mov ecx, 1
.t81_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 82: TEST8 je taken ----
    TEST_CASE t82_name
    mov al, 0xF0
    mov ecx, 0
    test al, 0x0F          ; AND=0 -> ZF=1
    je .t82_taken
    jmp .t82_check
.t82_taken:
    mov ecx, 1
.t82_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 83: AND8 js taken ----
    TEST_CASE t83_name
    mov al, 0x80
    mov ecx, 0
    and al, 0xFF           ; bit 7 set -> SF=1 (8-bit)
    js .t83_taken
    jmp .t83_check
.t83_taken:
    mov ecx, 1
.t83_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 84: ADD8 jc taken ----
    TEST_CASE t84_name
    mov al, 0xFF
    mov ecx, 0
    add al, 1              ; 8-bit wrap -> CF=1
    jc .t84_taken
    jmp .t84_check
.t84_taken:
    mov ecx, 1
.t84_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 85: SUB16 js taken ----
    TEST_CASE t85_name
    mov ax, 5
    mov ecx, 0
    sub ax, 100            ; negative in 16-bit -> SF=1
    js .t85_taken
    jmp .t85_check
.t85_taken:
    mov ecx, 1
.t85_check:
    CHECK_EQ_32 ecx, 1

    ; ================================================================
    ; Unsigned compound conditions (jbe, ja)
    ; ================================================================

    ; ---- Test 86: CMP32 jbe taken (below or equal: CF=1 or ZF=1) ----
    TEST_CASE t86_name
    mov eax, 5
    mov ecx, 0
    cmp eax, 5             ; equal -> ZF=1 -> jbe taken
    jbe .t86_taken
    jmp .t86_check
.t86_taken:
    mov ecx, 1
.t86_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 87: CMP32 jbe not-taken ----
    TEST_CASE t87_name
    mov eax, 100
    mov ecx, 0
    cmp eax, 5             ; 100 > 5 -> CF=0, ZF=0 -> jbe not taken
    jbe .t87_taken
    mov ecx, 1
    jmp .t87_check
.t87_taken:
    mov ecx, 0
.t87_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 88: CMP32 ja taken (above: CF=0 and ZF=0) ----
    TEST_CASE t88_name
    mov eax, 100
    mov ecx, 0
    cmp eax, 5             ; 100 > 5 unsigned -> ja taken
    ja .t88_taken
    jmp .t88_check
.t88_taken:
    mov ecx, 1
.t88_check:
    CHECK_EQ_32 ecx, 1

    ; ---- Test 89: CMP32 ja not-taken ----
    TEST_CASE t89_name
    mov eax, 5
    mov ecx, 0
    cmp eax, 5             ; equal -> ZF=1 -> ja not taken
    ja .t89_taken
    mov ecx, 1
    jmp .t89_check
.t89_taken:
    mov ecx, 0
.t89_check:
    CHECK_EQ_32 ecx, 1

    END_TESTS
