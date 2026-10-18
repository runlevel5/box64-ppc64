// SPDX-License-Identifier: MIT
// Native replacements for hot functions statically linked into specific 32-bit games.
// A hook is only installed when the guest function is found in the main ELF symbol table
// and its bytes match the exact build it was written for, so it can't affect anything else.
// Disable with BOX64_GAMEHOOKS=0.
#include <stdint.h>
#include <stddef.h>

#include "debug.h"
#include "box64context.h"
#include "elfloader.h"
#include "bridge.h"
#include "alternate.h"
#include "box32.h"
#include "x64emu.h"
#include "wrapper32.h"

static uint64_t fnv1a64(const uint8_t* p, size_t n)
{
    uint64_t h = 0xcbf29ce484222325ULL;
    for (size_t i = 0; i < n; ++i)
        h = (h ^ p[i]) * 0x100000001b3ULL;
    return h;
}

// ---- libtheoraplayer 1.0 decodeRGBX (Grim Fandango Remastered, GOG Linux 2.3.0.7) ---------------
// struct TheoraPixelTransform { unsigned char *raw, *y, *u, *v, *out; unsigned int w, h, rawStride, yStride, uStride, vStride; };
typedef struct theora_pixel_transform32_s {
    ptr_t raw, y, u, v, out;
    uint32_t w, h, rawStride, yStride, uStride, vStride;
} theora_pixel_transform32_t;

// YUV->RGB tables filled at runtime by the game (libtheoraplayer's static int tables),
// at the addresses the guest code uses (part of the verified bytes)
static const int32_t* tG_V; // 0xb280054
static const int32_t* tG_U; // 0xb280454
static const int32_t* tR_V; // 0xb280854
static const int32_t* tB_U; // 0xb280c54
static const int32_t* tY;   // 0xb281054

static inline uint8_t clamp13(int32_t s)
{
    int32_t x = s >> 13;
    if ((uint32_t)x > 255) x = (-x) >> 31; // same saturation as the guest code: <0 -> 0, >255 -> 255
    return (uint8_t)x;
}

// YUV 4:2:0 -> RGBX, two rows per iteration, X bytes left untouched, output stride w*4.
// All address arithmetic is done in 32 bits like the guest code.
static void native_decodeRGBX(theora_pixel_transform32_t* t)
{
    const uint32_t w = t->w, h = t->h;
    for (uint32_t row = 0; row < h; row += 2) {
        if (!w) continue;
        const uint8_t* y0 = from_ptrv((ptr_t)(t->y + t->yStride * row));
        const uint8_t* y1 = from_ptrv((ptr_t)(t->y + t->yStride * (row + 1)));
        const uint8_t* u = from_ptrv((ptr_t)(t->u + ((t->uStride * row) >> 1)));
        const uint8_t* v = from_ptrv((ptr_t)(t->v + ((t->vStride * row) >> 1)));
        uint8_t* o0 = from_ptrv((ptr_t)(t->out + w * 4 * row));
        uint8_t* o1 = from_ptrv((ptr_t)(t->out + w * 4 * (row + 1)));
        const uint32_t pairs = w / 2;
        for (uint32_t j = 0; j < pairs; ++j) {
            const int32_t rV = tR_V[v[j]];
            const int32_t gUV = tG_V[v[j]] + tG_U[u[j]];
            const int32_t bU = tB_U[u[j]];
            int32_t Y;
            Y = tY[y0[2 * j]];
            o0[8 * j + 0] = clamp13(Y + rV); o0[8 * j + 1] = clamp13(Y - gUV); o0[8 * j + 2] = clamp13(Y + bU);
            Y = tY[y0[2 * j + 1]];
            o0[8 * j + 4] = clamp13(Y + rV); o0[8 * j + 5] = clamp13(Y - gUV); o0[8 * j + 6] = clamp13(Y + bU);
            Y = tY[y1[2 * j]];
            o1[8 * j + 0] = clamp13(Y + rV); o1[8 * j + 1] = clamp13(Y - gUV); o1[8 * j + 2] = clamp13(Y + bU);
            Y = tY[y1[2 * j + 1]];
            o1[8 * j + 4] = clamp13(Y + rV); o1[8 * j + 5] = clamp13(Y - gUV); o1[8 * j + 6] = clamp13(Y + bU);
        }
    }
}

typedef struct gamehook32_s {
    const char* symbol;
    uint32_t size;
    uint64_t hash;
    void* native;
    wrapper_t wrapper;
    void (*setup)(void);
} gamehook32_t;

static void setup_decodeRGBX(void)
{
    tG_V = from_ptrv(0xb280054);
    tG_U = from_ptrv(0xb280454);
    tR_V = from_ptrv(0xb280854);
    tB_U = from_ptrv(0xb280c54);
    tY = from_ptrv(0xb281054);
}

static const gamehook32_t gamehooks32[] = {
    { "decodeRGBX", 0x2c0, 0xd093c74f420945f9ULL, native_decodeRGBX, vFp_32, setup_decodeRGBX },
};

void InstallGameHooks32(elfheader_t* h)
{
    if (!BOX64ENV(gamehooks) || !h)
        return;
    for (size_t i = 0; i < sizeof(gamehooks32) / sizeof(gamehooks32[0]); ++i) {
        const gamehook32_t* g = &gamehooks32[i];
        uintptr_t start = 0, end = 0;
        if (!ElfGetSymTabStartEnd32(h, &start, &end, g->symbol))
            continue;
        if (end - start != g->size || fnv1a64((const uint8_t*)start, g->size) != g->hash) {
            printf_log(LOG_INFO, "Game hook: %s found at %p but doesn't match the known build, not hooked\n", g->symbol, (void*)start);
            continue;
        }
        if (g->setup) g->setup();
        uintptr_t bridge = AddBridge(my_context->system, g->wrapper, g->native, 0, g->symbol);
        addAlternate((void*)start, (void*)bridge);
        printf_log(LOG_INFO, "Game hook: %s at %p redirected to native code\n", g->symbol, (void*)start);
    }
}
