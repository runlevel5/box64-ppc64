; test_32bit_into.asm - Test INTO opcode (32-bit only)
; This opcode is invalid in 64-bit mode.
;
; Opcodes tested:
;   CE = INTO (Interrupt on Overflow)
;
; INTO checks the OF flag:
;   - If OF=0, INTO is a no-op (execution continues normally)
;   - If OF=1, INTO triggers INT 4 (overflow exception)
;
; We test the OF=0 (no-op) path thoroughly. The OF=1 path would
; require a signal handler (SIGSEGV/SIGTRAP) which is beyond the
; scope of this simple test framework.

%include "test_framework_32.inc"

section .data
    t1_name: db "into nop when OF=0 (after xor)", 0
    t2_name: db "into nop preserves eax", 0
    t3_name: db "into nop preserves flags", 0
    t4_name: db "into nop after non-overflow add", 0

section .text
global _start
_start:
    INIT_TESTS

    ; ---- Test 1: INTO is a no-op when OF=0 (clear OF via xor) ----
    TEST_CASE t1_name
    xor eax, eax            ; OF=0, ZF=1, etc.
    db 0xCE                  ; INTO - should be a no-op since OF=0
    ; If we get here, INTO didn't trap - that's a pass.
    ; Use a sentinel value to prove we continued execution.
    mov eax, 0xCAFEBABE
    CHECK_EQ_32 eax, 0xCAFEBABE

    ; ---- Test 2: INTO preserves registers when OF=0 ----
    TEST_CASE t2_name
    mov eax, 0xDEADBEEF
    mov ebx, 0x12345678
    ; Clear OF explicitly: overflow flag is cleared by test instruction
    test eax, eax           ; clears OF
    db 0xCE                  ; INTO - no-op
    CHECK_EQ_32 eax, 0xDEADBEEF

    ; ---- Test 3: INTO does not modify flags when OF=0 ----
    TEST_CASE t3_name
    mov eax, 1
    test eax, eax           ; sets PF, clears ZF/SF/OF/CF
    SAVE_FLAGS
    mov ecx, [_fw_saved_flags]  ; save pre-INTO flags
    db 0xCE                  ; INTO - no-op since OF=0
    SAVE_FLAGS
    mov edx, [_fw_saved_flags]  ; post-INTO flags
    ; Compare relevant arithmetic flag bits
    and ecx, FLAGS_MASK_ARITH
    and edx, FLAGS_MASK_ARITH
    CHECK_EQ_32 edx, ecx

    ; ---- Test 4: INTO is a no-op after a non-overflowing add ----
    TEST_CASE t4_name
    mov eax, 100
    add eax, 50             ; 150, no overflow, OF=0
    db 0xCE                  ; INTO - no-op
    CHECK_EQ_32 eax, 150

    END_TESTS
