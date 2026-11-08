; Regression test: a signal landing right after a 64-bit write must not zero
; the upper half of that register. ADD EAX leaves its zero-up pending (the
; next instruction overwrites RAX), MOV RAX, imm64 then writes all 64 bits,
; and a load faults. The SIGSEGV handler records RAX from its ucontext and
; skips the 2-byte faulting load.
; Build: nasm -f elf64 -o test_signal_up32.o test_signal_up32.asm && ld.lld -m elf_x86_64 -o bin/test_signal_up32 test_signal_up32.o
%include "test_framework.inc"
%define UC_RIP 168
%define UC_RAX 144              ; gregs[REG_RAX]=13 -> 40+13*8
section .data
t1: db "handler sees full 64-bit RAX ", 0
t2: db "RAX after the handler ", 0
align 8
sigact: dq segv_handler, 0x04000004, sig_restorer, 0
seen_rax: dq 0
section .text
global _start
segv_handler:
    mov rax, [rdx + UC_RAX]
    mov [rel seen_rax], rax
    add qword [rdx + UC_RIP], 2
    ret
sig_restorer:
    mov eax, 15
    syscall
_start:
    INIT_TESTS
    mov eax, 13
    mov edi, 11
    lea rsi, [rel sigact]
    xor edx, edx
    mov r10d, 8
    syscall
    xor ecx, ecx
    mov rax, -1
    add eax, 1                  ; 32-bit write: zero-up skippable (overwritten next)
    mov rax, 0x1122334455667788 ; 64-bit write of a register stale at its entry
    mov edx, [rcx]              ; SIGSEGV, 2 bytes
    mov rbx, rax
    TEST_CASE t1
    mov rax, [rel seen_rax]
    CHECK_EQ_64 rax, 0x1122334455667788
    TEST_CASE t2
    mov rax, rbx
    CHECK_EQ_64 rax, 0x1122334455667788
    END_TESTS
