// Standalone test of the PPC64LE sigbus_specialcases() emulation (run natively on a POWER host):
//   gcc -DBOX32 -DCONFIG_64BIT -DDYNAREC -DPPC64LE -Isrc/include -Isrc -Isrc/wrapped/generated -Isrc/wrapped32/generated -O2 -std=gnu11 -c -o /tmp/sigtools.o src/libtools/sigtools.c
//   gcc -O1 -mcpu=power9 -o /tmp/sigbus_harness tests/ppc64le/sigbus_harness.c tests/ppc64le/sigbus_stubs.c /tmp/sigtools.o -lpthread && /tmp/sigbus_harness
// Harness for the PPC64LE sigbus_specialcases() emulation: each instruction faults on an unmapped
// base (r20), the SIGSEGV handler points r20 at an unaligned buffer and runs the real emulator.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <ucontext.h>
#include <stdlib.h>
#include <asm/ptrace.h>
int sigbus_specialcases(siginfo_t* info, void* ucntx, void* pc, void* fpsimd, void* db, uintptr_t x64pc, int is32bits);
static uint8_t buf[80] __attribute__((aligned(16)));
static const uintptr_t bad = 0x10;
static int fails = 0;
static void h(int sig, siginfo_t* si, void* uc_) {
    ucontext_t* uc = uc_;
    uc->uc_mcontext.gp_regs[20] = (uintptr_t)buf + 1;
    void* pc = (void*)uc->uc_mcontext.gp_regs[PT_NIP];
    if (!sigbus_specialcases(si, uc, pc, NULL, NULL, 0, 0)) { printf("UNHANDLED pc=%p inst=%08x\n", pc, *(uint32_t*)pc); exit(2); }
}
static void check(const char* n, const void* a, const void* b, int l) { if (memcmp(a, b, l)) { printf("FAIL %s\n", n); fails++; } else printf("PASS %s\n", n); }
#define BASE register uintptr_t base asm("r20") = bad
int main(void) {
    struct sigaction sa = {0}; sa.sa_sigaction = h; sa.sa_flags = SA_SIGINFO; sigaction(SIGSEGV, &sa, 0);
    uint8_t pat[16], pat2[16], tmp[16] __attribute__((aligned(16)));
    for (int i = 0; i < 16; i++) { pat[i] = 0xA0 + i; pat2[i] = 0x10 + i; }
    { BASE; __asm__ volatile("lxv 35, 0(%1)\n\tstxv 35, 0(%0)" :: "r"(base), "r"(pat) : "vs35", "memory"); check("stxv vs35 (VMX reg)", buf + 1, pat, 16); }
    { BASE; __asm__ volatile("lxv 5, 0(%1)\n\tstxv 5, 16(%0)" :: "r"(base), "r"(pat2) : "vs5", "memory"); check("stxv vs5 (FPR half)", buf + 17, pat2, 16); }
    { BASE; __asm__ volatile("xxlxor 36, 36, 36\n\tlxv 36, 0(%0)\n\tstxv 36, 0(%1)" :: "r"(base), "r"(tmp) : "vs36", "memory"); check("lxv vs36 (VMX reg)", tmp, pat, 16); }
    { BASE; __asm__ volatile("xxlxor 6, 6, 6\n\tlxv 6, 16(%0)\n\tstxv 6, 0(%1)" :: "r"(base), "r"(tmp) : "vs6", "memory"); check("lxv vs6 (FPR half)", tmp, pat2, 16); }
    double d = 3.14159; uint64_t dbits; memcpy(&dbits, &d, 8);
    { BASE; __asm__ volatile("lfd 7, 0(%1)\n\tstfd 7, 32(%0)" :: "r"(base), "r"(&d) : "fr7", "memory"); check("stfd", buf + 33, &dbits, 8); }
    { BASE; double o = 0; __asm__ volatile("lfd 8, 32(%0)\n\tstfd 8, 0(%1)" :: "r"(base), "r"(&o) : "fr8", "memory"); check("lfd", &o, &d, 8); }
    float f = 2.5f; uint32_t fbits; memcpy(&fbits, &f, 4);
    { BASE; __asm__ volatile("lfs 9, 0(%1)\n\tstfs 9, 40(%0)" :: "r"(base), "r"(&f) : "fr9", "memory"); check("stfs", buf + 41, &fbits, 4); }
    { BASE; float o = 0; __asm__ volatile("lfs 10, 40(%0)\n\tstfs 10, 0(%1)" :: "r"(base), "r"(&o) : "fr10", "memory"); check("lfs", &o, &f, 4); }
    buf[45] = 0x80; buf[46] = 0xFF;                       // halfword 0xFF80 at base+44
    { BASE; register int64_t o asm("r21"); __asm__ volatile("lha 21, 44(20)" : "=r"(o) : "r"(base) : "memory"); int64_t ov = o, e = -128; check("lha sign-extend", &ov, &e, 8); }
    buf[49] = 0x01; buf[50] = 0; buf[51] = 0; buf[52] = 0x80;   // word 0x80000001 at base+48
    { BASE; register int64_t o asm("r22"); __asm__ volatile("lwa 22, 48(20)" : "=r"(o) : "r"(base) : "memory"); int64_t ov = o, e = (int64_t)(int32_t)0x80000001; check("lwa sign-extend", &ov, &e, 8); }
    { BASE; register uintptr_t idx asm("r24") = 56; register uint64_t v asm("r23") = 0x1234; __asm__ volatile("sthbrx 23, 20, 24" :: "r"(base), "r"(idx), "r"(v) : "memory"); uint8_t e[2] = {0x12, 0x34}; check("sthbrx", buf + 57, e, 2); }
    { BASE; register uintptr_t idx asm("r24") = 56; register uint64_t o asm("r25"); __asm__ volatile("lhbrx 25, 20, 24" : "=r"(o) : "r"(base), "r"(idx) : "memory"); uint64_t ov = o, e = 0x1234; check("lhbrx", &ov, &e, 8); }
    { BASE; register uint64_t v asm("r23") = 0x1122334455667788ull; __asm__ volatile("std 23, 64(20)" :: "r"(base), "r"(v) : "memory"); uint64_t e = 0x1122334455667788ull; check("std (pre-existing path)", buf + 65, &e, 8); }
    printf("Result: %d failures\n", fails);
    return fails ? 1 : 0;
}
