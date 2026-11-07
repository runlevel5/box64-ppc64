; Regression test: a signal landing where the flags are already materialised
; must not recompute them from a stale deferred-flags record left in emu->df.
; A 16-bit TEST whose jump leaves the block writes its record to emu->df, a
; fused TEST leaves that record stale, UCOMISS writes ZF/PF/CF directly, then
; a load faults. The SIGSEGV handler records EFLAGS from its ucontext and
; skips the 2-byte faulting load; the code after it reads ZF again.
; Build: nasm -f elf64 -o test_signal_df.o test_signal_df.asm && ld.lld -m elf_x86_64 -o bin/test_signal_df test_signal_df.o
%include "test_framework.inc"

%define SYS_rt_sigaction 13
%define SYS_rt_sigreturn 15
%define SIGSEGV 11
%define SA_SIGINFO  0x00000004
%define SA_RESTORER 0x04000000
%define UC_RIP 168              ; uc_mcontext.gregs[REG_RIP]
%define UC_EFL 176              ; uc_mcontext.gregs[REG_EFL]

section .data
t1: db "handler sees ZF from UCOMISS, not the stale TEST record ", 0
t2: db "ZF after returning from the handler ", 0
align 4
zero_f: dd 0.0
align 8
sigact:
    dq segv_handler
    dq SA_SIGINFO | SA_RESTORER
    dq sig_restorer
    dq 0
seen_efl: dq 0

section .text
global _start

segv_handler:
    mov rax, [rdx + UC_EFL]
    mov [rel seen_efl], rax
    add qword [rdx + UC_RIP], 2 ; skip "mov eax, [rcx]"
    ret

sig_restorer:
    mov eax, SYS_rt_sigreturn
    syscall

bad_exit:
    mov eax, 60
    mov edi, 99
    syscall

_start:
    INIT_TESTS
    mov eax, SYS_rt_sigaction
    mov edi, SIGSEGV
    lea rsi, [rel sigact]
    xor edx, edx
    mov r10d, 8
    syscall

    mov r15d, 5                 ; nonzero: the 16-bit TEST record says ZF=0
    mov esi, 1
    xor ecx, ecx
    test r15w, r15w
    jz bad_exit                 ; leaves the block: record written to emu->df
    test rsi, rsi
    jz bad_exit                 ; fused: no record written, emu->df now stale
    pxor xmm3, xmm3
    ucomiss xmm3, [rel zero_f]  ; equal: ZF=1, PF=0, CF=0 in the flags register
    mov eax, [rcx]              ; SIGSEGV (2 bytes, skipped by the handler)
    setz bl
    movzx ebx, bl

    TEST_CASE t1
    mov rax, [rel seen_efl]
    and eax, ZF
    CHECK_EQ_64 rax, ZF
    TEST_CASE t2
    mov rax, rbx
    CHECK_EQ_64 rax, 1
    END_TESTS
