// stubs for the box64 symbols sigtools.c references but the harness never reaches
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
void* my_context = 0;
int box64_log = 0;
void printf_log_prefix(int prefix, int level, const char* fmt, ...) { va_list ap; va_start(ap, fmt); vfprintf(stderr, fmt, ap); va_end(ap); }
const char* ppc64le_print(uint32_t inst, uintptr_t pc) { return "?"; }
uintptr_t getX64Address(void* db, uintptr_t addr) { return 0; }
int getProtection(uintptr_t addr) { return 0; }
void* FindDynablockFromNativeAddress(void* addr) { return 0; }
int decode_opcode(uintptr_t rip, int is32bits) { return 0; }
#include <stdlib.h>
int arch_unaligned(void* db, uintptr_t x64pc) { return 0; }
char box64env[8192];
char mutex_blocks[256];
char mutex_prot[256];
int checkNolockMutex(void* m) { return 0; }
int checkUnlockMutex(void* m) { return 0; }
void* customCalloc(size_t n, size_t s) { return calloc(n, s); }
void* customMalloc(size_t s) { return malloc(s); }
void* customRealloc(void* p, size_t s) { return realloc(p, s); }
void customFree(void* p) { free(p); }
void MarkDynablock(void* db) {}
void PrintfFtrace(int prefix, const char* fmt, ...) { va_list ap; va_start(ap, fmt); vfprintf(stderr, fmt, ap); va_end(ap); }
