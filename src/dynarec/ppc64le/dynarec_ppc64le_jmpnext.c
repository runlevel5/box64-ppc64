// SPDX-License-Identifier: MIT
#include <stdint.h>

#include "ppc64le_emitter.h"

#define EMIT(A)       \
    do {              \
        *block = (A); \
        ++block;      \
    } while (0)
void CreateJmpNext(void* addr, void* next)
{
    uint32_t* block = (uint32_t*)addr;
    // Every jump to a jmpnext stub is an indirect branch through CTR (MTCTR + BCTR/BCTRL:
    // jump table dispatch, prolog entry, native_next), so on entry CTR holds the address
    // of this stub. Use it to locate the target pointer stored at 'next', no BCL/MFLR needed.
    //   MFCTR r12           -> r12 = addr
    //   LD r12, offset(r12) -> r12 = *(next) = target
    //   MTCTR r12
    //   BCTR
    // 4 instructions = 16 bytes: the stub fits the generic JMPNEXT_SIZE layout
    // (block ptr, 16 bytes of code, target ptr) that the dynacache loader expects.
    int reg = 12;   // r12 is scratch
    intptr_t offset = (intptr_t)next - (intptr_t)addr;
    MFCTR(reg);
    LD(reg, (int16_t)offset, reg);
    MTCTR(reg);
    BCTR();
}
