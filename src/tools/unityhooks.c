// SPDX-License-Identifier: MIT
// Native replacements for hot math functions of a specific UnityPlayer.so build.
// Each replacement follows the guest code instruction by instruction (same operations, same
// operand pairing, no fused multiply-add: see the pragmas below), so the
// results are bit-identical to the x86 code. A hook is only installed when the guest function
// bytes match the build it was written for. Disable with BOX64_UNITYHOOKS=0; BOX64_UNITYHOOKS=2
// also runs the guest code on every call and logs any difference (verification mode).
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "debug.h"
#include "env.h"
#include "box64context.h"
#include "elfloader.h"
#include "bridge.h"
#include "alternate.h"
#include "callback.h"
#include "wrapper.h"

// a fused multiply-add rounds once instead of twice: the results would differ from the x86 code
#if defined(__clang__)
#pragma clang fp contract(off)
#elif defined(__GNUC__)
#pragma GCC optimize("fp-contract=off")
#endif

typedef float v4 __attribute__((vector_size(16)));

// SHUFPS x,x,imm (same register)
#define SHUF(a, imm) __builtin_shufflevector((a), (a), (imm) & 3, ((imm) >> 2) & 3, ((imm) >> 4) & 3, ((imm) >> 6) & 3)
// SHUFPD x,x,1
#define SWAPQ(a) __builtin_shufflevector((a), (a), 2, 3, 0, 1)
// the last row stores of the guest code: {a0, a1, a2, w}
#define ROW3(a, w) ((v4) { (a)[0], (a)[1], (a)[2], (w) })

static uint64_t fnv1a64(const uint8_t* p, size_t n)
{
    uint64_t h = 0xcbf29ce484222325ULL;
    for (size_t i = 0; i < n; ++i)
        h = (h ^ p[i]) * 0x100000001b3ULL;
    return h;
}

// ---- Unity 2019.4.41f1 (fb553f8fdd6c) UnityPlayer.so, Pillars of Eternity GOG Linux -------------
static uintptr_t up_CompleteFenceInternal; // CompleteFenceInternal(JobFence&, WorkStealMode)
static uintptr_t up_ClearFenceWithoutSync; // ClearFenceWithoutSync(JobFence&)

// TransformHierarchy: +0x00 JobFence, +0x18 TransformX* (pos, rot, scale: 3 x 16 bytes), +0x20 int* parent
// Transform: +0x38 TransformHierarchy*, +0x40 index
static void native_GetLocalToWorldMatrix(void* self, float* out)
{
    const v4 C310 = { 0.f, 1.f, 0.f, 0.f };
    const v4 C350 = { -2.f, 2.f, -2.f, 0.f };
    const v4 C360 = { -2.f, 2.f, 2.f, 0.f };
    const v4 C370 = { -2.f, -2.f, 2.f, 0.f };
    const v4 C380 = { 2.f, -2.f, 2.f, 0.f };
    const v4 C390 = { 2.f, -2.f, -2.f, 0.f };
    const v4 C3A0 = { 2.f, 2.f, -2.f, 0.f };
    const v4 C3B0 = { 0.f, 0.f, 1.f, 0.f };
    const v4 ONE = { 1.f, 0.f, 0.f, 0.f };

    uintptr_t h = *(uintptr_t*)((uintptr_t)self + 0x38);
    if (*(uint64_t*)h) {
        RunFunctionFmt(up_CompleteFenceInternal, "pi", (void*)h, 0);
        RunFunctionFmt(up_ClearFenceWithoutSync, "p", (void*)h);
        h = *(uintptr_t*)((uintptr_t)self + 0x38);
    }
    const v4* tx = *(const v4**)(h + 0x18);
    const int32_t* parent = *(const int32_t**)(h + 0x20);
    uint32_t idx = *(uint32_t*)((uintptr_t)self + 0x40);
    const v4* t = tx + 3 * (uintptr_t)idx;

    v4 x13 = t[0], x2 = t[1], x10 = t[2];
    v4 x6 = SHUF(x2, 0xf1);
    v4 x5 = SWAPQ(x2);
    v4 x8 = SHUF(x2, 0xdb);
    v4 x4 = SHUF(x2, 0xd5);
    v4 x1 = C350 * x4;
    x1 = x1 * x6;
    v4 x7 = SHUF(x2, 0xea);
    v4 x3 = C360 * x7;
    x3 = x3 * x5;
    x3 = x3 + x1;
    v4 x9 = ONE + x3;
    x7 = x7 * C370;
    x7 = x7 * x8;
    x2 = SHUF(x2, 0xc0);
    x1 = C380 * x2;
    x1 = x1 * x6;
    x1 = x1 + x7;
    x1 = x1 + C310;
    x2 = x2 * C390;
    x2 = x2 * x5;
    x4 = x4 * C3A0;
    x4 = x4 * x8;
    x4 = x4 + x2;
    x4 = x4 + C3B0;
    x3 = SHUF(x10, 0xc0) * x9;
    x2 = SHUF(x10, 0xd5) * x1;
    x10 = SHUF(x10, 0xea) * x4;

    int32_t p = parent[idx];
    while (p >= 0) {
        const v4* pt = tx + 3 * (intptr_t)p;
        v4 q = pt[1];
        v4 y1 = SHUF(q, 0xf1);
        v4 y4 = SWAPQ(q);
        v4 y8 = SHUF(q, 0xd5);
        v4 y5 = y8 * C350;
        v4 y11 = SHUF(q, 0xea);
        y5 = y5 * y1;
        v4 y6 = SHUF(q, 0xc0);
        v4 y12 = y6 * C380;
        y12 = y12 * y1;
        y1 = y11 * C360;
        y1 = y1 * y4;
        y6 = y6 * C390;
        y6 = y6 * y4;
        y1 = y1 + y5;
        v4 y7 = SHUF(q, 0xdb);
        y11 = y11 * C370;
        y11 = y11 * y7;
        y12 = y12 + y11;
        v4 s = pt[2];
        y8 = y8 * C3A0;
        y8 = y8 * y7;
        y12 = y12 + C310;
        y8 = y8 + y6;
        y8 = y8 + C3B0;
        y1 = y1 + ONE;
        y7 = SHUF(s, 0xc0) * y1;  // scaled rotation rows of the parent
        y6 = SHUF(s, 0xd5) * y12;
        y5 = SHUF(s, 0xea) * y8;
        // child rows (x3, x2, x10) and position (x13) times the parent rows
        v4 a1 = SHUF(x13, 0xc0) * y7;
        v4 a0 = SHUF(x13, 0xea) * y5;
        x13 = SHUF(x13, 0xd5) * y6;
        x13 = x13 + a0;
        v4 b4 = SHUF(x3, 0xc0) * y7;
        v4 b0 = SHUF(x3, 0xea) * y5;
        x3 = SHUF(x3, 0xd5) * y6;
        x3 = x3 + b0;
        x13 = x13 + a1;
        v4 c0 = SHUF(x2, 0xc0);
        v4 c1 = SHUF(x2, 0xea) * y5;
        x2 = SHUF(x2, 0xd5) * y6;
        x2 = x2 + c1;
        v4 d1 = SHUF(x10, 0xc0);
        c0 = c0 * y7;
        d1 = d1 * y7;
        v4 d7 = SHUF(x10, 0xea) * y5;
        x3 = x3 + b4;
        x10 = SHUF(x10, 0xd5) * y6;
        x10 = x10 + d7;
        x2 = x2 + c0;
        x10 = x10 + d1;
        x13 = x13 + pt[0];
        p = parent[p];
    }
    v4 r;
    r = ROW3(x3, 0.f);  memcpy(out + 0, &r, 16);
    r = ROW3(x2, 0.f);  memcpy(out + 4, &r, 16);
    r = ROW3(x10, 0.f); memcpy(out + 8, &r, 16);
    r = ROW3(x13, 1.f); memcpy(out + 12, &r, 16);
}

// ---- verification mode: run both, compare the bytes --------------------------------------------
static uintptr_t up_GetLocalToWorldMatrix;
static uint64_t verify_calls, verify_bad;

static void verify_GetLocalToWorldMatrix(void* self, float* out)
{
    float mine[16];
    native_GetLocalToWorldMatrix(self, mine);
    RunFunctionFmtNoAlt(up_GetLocalToWorldMatrix, "pp", self, out);
    uint64_t n = __atomic_add_fetch(&verify_calls, 1, __ATOMIC_RELAXED);
    if (memcmp(mine, out, sizeof(mine))) {
        uint64_t b = __atomic_add_fetch(&verify_bad, 1, __ATOMIC_RELAXED);
        if (b <= 8) {
            printf_log(LOG_NONE, "Unity hook verify: GetLocalToWorldMatrix mismatch #%llu (call %llu):\n", (unsigned long long)b, (unsigned long long)n);
            for (int i = 0; i < 16; ++i)
                if (memcmp(&mine[i], &out[i], 4))
                    printf_log(LOG_NONE, "  [%d] native %a guest %a\n", i, mine[i], out[i]);
        }
    }
    if (!(n & ((1 << 20) - 1)))
        printf_log(LOG_NONE, "Unity hook verify: GetLocalToWorldMatrix %llu calls, %llu mismatches\n", (unsigned long long)n, (unsigned long long)verify_bad);
}

typedef struct unityhook_s {
    const char* name;
    uintptr_t start;
    size_t size;
    uint64_t hash;
    wrapper_t wrapper;
    void* native;
    void* verify;
    uintptr_t* guest; // where to keep the guest address, for verification
} unityhook_t;

static const unityhook_t unityhooks[] = {
    { "Transform::GetLocalToWorldMatrix", 0x103cac0, 0x2e5, 0x72de05b927c6dae2ULL, vFpp, native_GetLocalToWorldMatrix, verify_GetLocalToWorldMatrix, &up_GetLocalToWorldMatrix },
};
#define N_UNITYHOOKS (sizeof(unityhooks) / sizeof(unityhooks[0]))

// called once UnityPlayer.so is loaded, before any of its code runs
void InstallUnityHooks(elfheader_t* h)
{
    if (!BOX64ENV(unityhooks) || !h)
        return;
    uintptr_t delta = (uintptr_t)GetElfDelta(h);
    for (size_t i = 0; i < N_UNITYHOOKS; ++i) {
        const unityhook_t* u = &unityhooks[i];
        uint64_t hash = fnv1a64((const uint8_t*)(delta + u->start), u->size);
        if (hash != u->hash) {
            printf_log(LOG_DEBUG, "Unity hook: %s doesn't match the known build (hash 0x%016llx)\n", u->name, (unsigned long long)hash);
            continue;
        }
        up_CompleteFenceInternal = delta + 0x9895c0;
        up_ClearFenceWithoutSync = delta + 0x9895b0;
        *u->guest = delta + u->start;
        void* fnc = (BOX64ENV(unityhooks) == 2) ? u->verify : u->native;
        uintptr_t bridge = AddBridge(my_context->system, u->wrapper, fnc, 0, u->name);
        addAlternate((void*)(delta + u->start), (void*)bridge);
        printf_log(LOG_INFO, "Unity hook: %s at %p redirected to native code%s\n", u->name, (void*)(delta + u->start), (fnc == u->verify) ? " (verification mode)" : "");
    }
}
