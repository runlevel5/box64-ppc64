// SPDX-License-Identifier: MIT
#include <stdlib.h>
#include <stddef.h>
#include <stdint.h>

#include "alternate.h"
#include "custommem.h"
#include "khash.h"
#ifdef DYNAREC
#include "box64context.h"
#include "bridge.h"
#endif
#include "debug.h"

// Alternate address handling
typedef struct {
    void* addr;
    #ifdef HAVE_ALTJUMP
    uintptr_t jump;
    void* data;
    #endif
} my_alternate_t;
KHASH_MAP_INIT_INT64(alternate, my_alternate_t)
static kh_alternate_t *my_alternates = NULL;

// Bloom filter for fast negative lookups in hasAlternate().
// 256 bits (4 x uint64_t) with 3 hash probes per key.
// The alternate table is small (typically <100 entries) and populated
// only at init/library-load time, so the bloom filter eliminates
// virtually all khash lookups on the hot path (>99.9% are misses).
static uint64_t alternate_bloom[4] = {0, 0, 0, 0};

static inline void bloom_set(uintptr_t key) {
    // Three independent hash probes from different bit ranges of the key.
    // Each selects one of 256 bits (2 bits for word index, 6 bits for bit position).
    uint32_t h1 = (uint32_t)(key ^ (key >> 17));
    uint32_t h2 = (uint32_t)(key ^ (key >> 31));
    uint32_t h3 = (uint32_t)((key >> 11) ^ (key >> 47));
    alternate_bloom[(h1 >> 6) & 3] |= (uint64_t)1 << (h1 & 63);
    alternate_bloom[(h2 >> 6) & 3] |= (uint64_t)1 << (h2 & 63);
    alternate_bloom[(h3 >> 6) & 3] |= (uint64_t)1 << (h3 & 63);
}

static inline int bloom_test(uintptr_t key) {
    uint32_t h1 = (uint32_t)(key ^ (key >> 17));
    uint32_t h2 = (uint32_t)(key ^ (key >> 31));
    uint32_t h3 = (uint32_t)((key >> 11) ^ (key >> 47));
    if(!(alternate_bloom[(h1 >> 6) & 3] & ((uint64_t)1 << (h1 & 63)))) return 0;
    if(!(alternate_bloom[(h2 >> 6) & 3] & ((uint64_t)1 << (h2 & 63)))) return 0;
    if(!(alternate_bloom[(h3 >> 6) & 3] & ((uint64_t)1 << (h3 & 63)))) return 0;
    return 1;  // maybe present — must check khash to confirm
}

int hasAlternate(void* addr) {
    if(!my_alternates)
        return 0;
    if(!bloom_test((uintptr_t)addr))
        return 0;
    khint_t k = kh_get(alternate, my_alternates, (uintptr_t)addr);
    if(k==kh_end(my_alternates))
        return 0;
    return 1;
}

void* getAlternate(void* addr) {
    if(!my_alternates)
        return addr;
    khint_t k = kh_get(alternate, my_alternates, (uintptr_t)addr);
    if(k!=kh_end(my_alternates))
        return kh_value(my_alternates, k).addr;
    return addr;
}
void addAlternate(void* addr, void* alt) {
    if(!my_alternates) {
        my_alternates = kh_init(alternate);
    }
    if(addr==alt)
        return; // nothing to do, alt is same as addr, but it's certainly an issue somewere!
    int ret;
    khint_t k = kh_put(alternate, my_alternates, (uintptr_t)addr, &ret);
    if(!ret)    // already there
        return;
    kh_value(my_alternates, k).addr = alt;
    bloom_set((uintptr_t)addr);
    #ifdef HAVE_ALTJUMP
    kh_value(my_alternates, k).jump = AddAltJump(my_context->alternates, (uintptr_t)addr, (uintptr_t)alt);
    #endif
    #ifdef DYNAREC
    // a dynablock may have been published before this alternate was known.
    // force the next dispatch to rebuild the entry with the alternate target.
    setJumpTableDefault64(addr);
    #endif
}

void addCheckAlternate(void* addr, void* alt) {
    if(!hasAlternate(addr))
        addAlternate(addr, alt);
}

void cleanAlternate() {
    if(my_alternates) {
        kh_destroy(alternate, my_alternates);
        my_alternates = NULL;
    }
    alternate_bloom[0] = 0;
    alternate_bloom[1] = 0;
    alternate_bloom[2] = 0;
    alternate_bloom[3] = 0;
}

#ifdef HAVE_ALTJUMP
#include "bridge_private.h"
uintptr_t getAlternateJump(void* addr, int is32bits) {
    if(!my_alternates)
        return 0;
    khint_t k = kh_get(alternate, my_alternates, (uintptr_t)addr);
    if(k!=kh_end(my_alternates)) {
        uintptr_t ret = kh_value(my_alternates, k).jump;
        if(is32bits) ret += offsetof(onebridge_t, FF_2);
        return ret;
    }
    return 0;
}
void* getAlternateData(void* addr)
{
    if(!my_alternates)
        return (void*)-1LL;
    khint_t k = kh_get(alternate, my_alternates, (uintptr_t)addr);
    if(k!=kh_end(my_alternates)) {
        return kh_value(my_alternates, k).data;
    }
    return (void*)-1LL;
}
void setAlternateData(void* addr, void* data)
{
    if(!my_alternates)
        return;
    khint_t k = kh_get(alternate, my_alternates, (uintptr_t)addr);
    if(k!=kh_end(my_alternates)) {
        kh_value(my_alternates, k).data = data;
    }
}

#endif