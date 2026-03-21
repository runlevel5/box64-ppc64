; test_framework_32.inc - 32-bit NASM test framework for box64 dynarec testing
; Uses raw Linux i386 syscalls only (no libc dependency)
; Include this file at the top of each 32-bit test .asm file
;
; Usage:
;   %include "test_framework_32.inc"
;   section .data
;   test_name: db "My Test", 0
;   section .text
;   global _start
;   _start:
;       INIT_TESTS
;       ; ... test code using TEST_CASE, CHECK_EQ_32, etc. ...
;       END_TESTS
;
; All 8 general-purpose registers (eax-edi) are available to tests.
; Framework state is stored in .bss variables, not dedicated registers.
; Helper functions save/restore all registers they clobber.

BITS 32

;; ============================================================
;; Data section additions
;; ============================================================
section .data
    _fw_pass_msg: db "  PASS", 10, 0
    _fw_fail_msg: db "  FAIL", 10, 0
    _fw_expect_msg: db "  expected=0x", 0
    _fw_got_msg: db " got=0x", 0
    _fw_summary_msg: db "Result: ", 0
    _fw_slash: db "/", 0
    _fw_nl: db 10, 0
    _fw_colon_sp: db ": ", 0
    _fw_hex_chars: db "0123456789abcdef"

section .bss
    _fw_hexbuf: resb 20        ; buffer for hex conversion
    _fw_pass_count: resd 1     ; pass counter
    _fw_total_count: resd 1    ; total test counter
    _fw_saved_flags: resd 1    ; saved EFLAGS

section .text

;; ============================================================
;; Print a null-terminated string at address in esi
;; Saves and restores all registers it clobbers.
;; ============================================================
_fw_print_str:
    push eax
    push ebx
    push ecx
    push edx
    ; count length
    mov ecx, esi
.len_loop:
    cmp byte [ecx], 0
    je .len_done
    inc ecx
    jmp .len_loop
.len_done:
    sub ecx, esi
    mov edx, ecx       ; length
    mov ecx, esi        ; buffer
    mov ebx, 1          ; stdout
    mov eax, 4          ; sys_write
    int 0x80
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

;; ============================================================
;; Print 32-bit value in eax as hex (8 digits)
;; Saves and restores all registers it clobbers.
;; ============================================================
_fw_print_hex32:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    mov ebx, eax
    mov esi, _fw_hexbuf
    mov ecx, 8
.hex_loop:
    rol ebx, 4
    mov eax, ebx
    and eax, 0xF
    mov al, byte [_fw_hex_chars + eax]
    mov byte [esi], al
    inc esi
    dec ecx
    jnz .hex_loop
    mov byte [esi], 0   ; null terminate
    mov esi, _fw_hexbuf
    call _fw_print_str
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

;; ============================================================
;; Print decimal value in eax (up to 999)
;; Saves and restores all registers it clobbers.
;; ============================================================
_fw_print_dec:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    mov esi, _fw_hexbuf + 10
    mov byte [esi], 0
    dec esi
    mov ebx, eax
    test ebx, ebx
    jnz .dec_loop
    ; handle zero
    mov byte [esi], '0'
    jmp .dec_done
.dec_loop:
    test ebx, ebx
    jz .dec_done_inc
    xor edx, edx
    mov eax, ebx
    mov ecx, 10
    div ecx
    add edx, '0'
    mov byte [esi], dl
    dec esi
    mov ebx, eax
    jmp .dec_loop
.dec_done_inc:
    inc esi
.dec_done:
    call _fw_print_str
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

;; ============================================================
;; Macros
;; ============================================================

;; Initialize test framework
%macro INIT_TESTS 0
    mov dword [_fw_pass_count], 0
    mov dword [_fw_total_count], 0
%endmacro

;; Start a named test case. name_label should be a label to a db string.
;; TEST_CASE test_name_label
%macro TEST_CASE 1
    inc dword [_fw_total_count]
    push esi
    mov esi, %1
    call _fw_print_str
    pop esi
%endmacro

;; CHECK_EQ_32 actual_reg, expected_value
;; Compares reg32 to immediate, prints PASS/FAIL
;; Works with any register including eax.
%macro CHECK_EQ_32 2
    push eax
    push esi
    cmp %1, %2
    jne %%fail
    mov esi, _fw_pass_msg
    call _fw_print_str
    inc dword [_fw_pass_count]
    jmp %%done
%%fail:
    mov esi, _fw_fail_msg
    call _fw_print_str
    mov esi, _fw_expect_msg
    call _fw_print_str
    mov eax, %2
    call _fw_print_hex32
    mov esi, _fw_got_msg
    call _fw_print_str
    mov eax, %1
    call _fw_print_hex32
    mov esi, _fw_nl
    call _fw_print_str
%%done:
    pop esi
    pop eax
%endmacro

;; SAVE_FLAGS - save EFLAGS to _fw_saved_flags
;; Must be called immediately after the instruction under test
;; (before any cmp/test/etc. that would modify flags)
%macro SAVE_FLAGS 0
    pushfd
    pop dword [_fw_saved_flags]
%endmacro

;; CHECK_FLAGS_EQ mask, expected_masked_value
;; Checks that (saved_flags & mask) == expected
%macro CHECK_FLAGS_EQ 2
    push eax
    push ecx
    push esi
    mov eax, [_fw_saved_flags]
    and eax, %1             ; mask
    mov ecx, %2             ; expected
    cmp eax, ecx
    jne %%fail
    mov esi, _fw_pass_msg
    call _fw_print_str
    inc dword [_fw_pass_count]
    jmp %%done
%%fail:
    mov esi, _fw_fail_msg
    call _fw_print_str
    mov esi, _fw_expect_msg
    call _fw_print_str
    mov eax, %2
    call _fw_print_hex32
    mov esi, _fw_got_msg
    call _fw_print_str
    mov eax, [_fw_saved_flags]
    and eax, %1
    call _fw_print_hex32
    mov esi, _fw_nl
    call _fw_print_str
%%done:
    pop esi
    pop ecx
    pop eax
%endmacro

;; Print summary and exit
%macro END_TESTS 0
    ; Print summary
    mov esi, _fw_summary_msg
    call _fw_print_str
    mov eax, [_fw_pass_count]
    call _fw_print_dec
    mov esi, _fw_slash
    call _fw_print_str
    mov eax, [_fw_total_count]
    call _fw_print_dec
    mov esi, _fw_nl
    call _fw_print_str
    ; Exit with 0 if all passed, 1 otherwise
    mov eax, [_fw_pass_count]
    cmp eax, [_fw_total_count]
    je %%all_pass
    mov ebx, 1
    jmp %%do_exit
%%all_pass:
    xor ebx, ebx
%%do_exit:
    mov eax, 1          ; sys_exit
    int 0x80
%endmacro

;; Flag bit constants
%define CF 0x0001
%define PF 0x0004
%define AF 0x0010
%define ZF 0x0040
%define SF 0x0080
%define OF 0x0800
%define FLAGS_MASK_ARITH (CF|PF|AF|ZF|SF|OF)
%define FLAGS_MASK_LOGIC (CF|PF|ZF|SF|OF)
