// SPDX-License-Identifier: MIT
// Native replacements for hot functions statically linked into specific 32-bit games.
// A hook is only installed when the guest function is found in the main ELF symbol table
// and its bytes match the exact build it was written for, so it can't affect anything else.
// Disable with BOX64_GAMEHOOKS=0.
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <dlfcn.h>
#include <pthread.h>

#include "debug.h"
#include "box64context.h"
#include "elfloader.h"
#include "bridge.h"
#include "alternate.h"
#include "box32.h"
#include "x64emu.h"
#include "wrapper32.h"
#include "emu/x64emu_private.h"
#include "emu/x87emu_private.h"
#include "regs.h"

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
    x = x < 0 ? 0 : x;     // same saturation as the guest code: <0 -> 0, >255 -> 255 (branch-free: isel)
    x = x > 255 ? 255 : x;
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

// ---- libtheora 1.1 decoder API (statically linked in the same game) -> host libtheoradec ---------
// The decoder context and setup info are opaque: the guest gets 32-bit hash handles for them.
// th_info has no pointer nor long, so its layout is the same on both sides. ogg_packet and
// th_img_plane are converted. Decoded planes live in native memory the guest can't reach, so
// each frame is copied (compact, top-down) into a per-decoder buffer in the 32-bit space.
typedef struct h_ogg_packet_s { unsigned char* packet; long bytes, b_o_s, e_o_s; int64_t granulepos, packetno; } h_ogg_packet;
typedef struct h_th_comment_s { char** user_comments; int* comment_lengths; int comments; char* vendor; } h_th_comment;
typedef struct h_th_img_plane_s { int width, height, stride; unsigned char* data; } h_th_img_plane;
#pragma pack(push, 4)
typedef struct g_ogg_packet_s { ptr_t packet; int32_t bytes, b_o_s, e_o_s; int64_t granulepos, packetno; } g_ogg_packet;
#pragma pack(pop)
typedef struct g_th_img_plane_s { int32_t width, height, stride; ptr_t data; } g_th_img_plane;
_Static_assert(sizeof(g_ogg_packet) == 32, "i386 ogg_packet layout");
_Static_assert(sizeof(g_th_img_plane) == 16, "i386 th_img_plane layout");

#define TH_EIMPL              (-23)
#define TH_DECCTL_SET_STRIPE_CB 7

static int (*h_headerin)(void* info, h_th_comment* tc, void** setup, h_ogg_packet* op);
static void* (*h_alloc)(const void* info, const void* setup);
static void (*h_free)(void* dec);
static int (*h_ctl)(void* dec, int req, void* buf, size_t sz);
static int (*h_packetin)(void* dec, const h_ogg_packet* op, int64_t* granpos);
static int (*h_ycbcr_out)(void* dec, h_th_img_plane* ycbcr);
static void (*h_setup_free)(void* setup);
static int64_t (*h_granule_frame)(void* encdec, int64_t granpos);
static double (*h_granule_time)(void* encdec, int64_t granpos);
static void (*h_comment_init)(h_th_comment* tc);
static void (*h_comment_clear)(h_th_comment* tc);

typedef struct theora_dec_s {
    void* dec;
    uint8_t* low;   // last decoded frame, in the 32-bit space
    size_t lowsz;
} theora_dec_t;

#define ARG32(i) from_ptri(ptr_t, R_ESP + 4 + 4 * (i))
typedef union { int64_t i; uint32_t d[2]; } gh_ui64_t;

static theora_dec_t* dec_from_handle(ptr_t h) { return (theora_dec_t*)from_hash(h); }

static void conv_packet(h_ogg_packet* h, const g_ogg_packet* g)
{
    h->packet = from_ptrv(g->packet);
    h->bytes = g->bytes;
    h->b_o_s = g->b_o_s;
    h->e_o_s = g->e_o_s;
    h->granulepos = g->granulepos;
    h->packetno = g->packetno;
}

// native comment state, keyed by the address of the guest th_comment (which stays empty)
#define N_THCOMMENT 16
static struct { ptr_t key; int used; h_th_comment tc; } th_comments[N_THCOMMENT];
static int th_comment_next = 0;
static pthread_mutex_t th_comment_mutex = PTHREAD_MUTEX_INITIALIZER;

static h_th_comment* get_th_comment(ptr_t key, int reset)
{
    pthread_mutex_lock(&th_comment_mutex);
    int idx = -1;
    for (int i = 0; i < N_THCOMMENT; ++i)
        if (th_comments[i].used && th_comments[i].key == key) { idx = i; break; }
    if (idx < 0) {
        idx = th_comment_next;
        th_comment_next = (th_comment_next + 1) % N_THCOMMENT;
        if (th_comments[idx].used) h_comment_clear(&th_comments[idx].tc);
        th_comments[idx].used = 1;
        th_comments[idx].key = key;
        h_comment_init(&th_comments[idx].tc);
    } else if (reset) {
        h_comment_clear(&th_comments[idx].tc);
        h_comment_init(&th_comments[idx].tc);
    }
    h_th_comment* ret = &th_comments[idx].tc;
    pthread_mutex_unlock(&th_comment_mutex);
    return ret;
}

// int th_decode_headerin(th_info*, th_comment*, th_setup_info**, ogg_packet*)
static void w_th_decode_headerin(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    ptr_t info = ARG32(0), tc = ARG32(1), setup = ARG32(2), op = ARG32(3);
    h_ogg_packet hop;
    const g_ogg_packet* gop = op ? (const g_ogg_packet*)from_ptrv(op) : NULL;
    if (gop) conv_packet(&hop, gop);
    // the info header (0x80) starts a new stream: forget the comments of a previous one
    int first = gop && gop->bytes > 0 && gop->packet && ((uint8_t*)from_ptrv(gop->packet))[0] == 0x80;
    h_th_comment* htc = tc ? get_th_comment(tc, first) : NULL;
    ptr_t* slot = setup ? (ptr_t*)from_ptrv(setup) : NULL;
    void* hsetup = slot ? (void*)from_hash(*slot) : NULL;
    int ret = h_headerin(info ? from_ptrv(info) : NULL, htc, slot ? &hsetup : NULL, gop ? &hop : NULL);
    if (slot) *slot = to_hash((uintptr_t)hsetup);
    R_EAX = (uint32_t)ret;
}

// th_dec_ctx* th_decode_alloc(const th_info*, const th_setup_info*)
static void w_th_decode_alloc(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    ptr_t info = ARG32(0), setup = ARG32(1);
    void* dec = h_alloc(info ? from_ptrv(info) : NULL, (void*)from_hash(setup));
    if (!dec) { R_EAX = 0; return; }
    theora_dec_t* d = box_calloc(1, sizeof(theora_dec_t));
    d->dec = dec;
    R_EAX = to_hash((uintptr_t)d);
}

// void th_decode_free(th_dec_ctx*)
static void w_th_decode_free(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    theora_dec_t* d = dec_from_handle(ARG32(0));
    if (!d) return;
    to_hash_d((uintptr_t)d);
    h_free(d->dec);
    if (d->low) box32_free(d->low);
    box_free(d);
}

// void th_setup_free(th_setup_info*)
static void w_th_setup_free(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    void* s = (void*)from_hash(ARG32(0));
    if (!s) return;
    to_hash_d((uintptr_t)s);
    h_setup_free(s);
}

// int th_decode_ctl(th_dec_ctx*, int, void*, size_t)
static void w_th_decode_ctl(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    theora_dec_t* d = dec_from_handle(ARG32(0));
    int req = (int)ARG32(1);
    ptr_t buf = ARG32(2);
    size_t sz = ARG32(3);
    if (req == TH_DECCTL_SET_STRIPE_CB) { R_EAX = (uint32_t)TH_EIMPL; return; } // guest callbacks: not bridged
    R_EAX = (uint32_t)h_ctl(d ? d->dec : NULL, req, buf ? from_ptrv(buf) : NULL, sz);
}

// int th_decode_packetin(th_dec_ctx*, const ogg_packet*, ogg_int64_t*)
static void w_th_decode_packetin(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    theora_dec_t* d = dec_from_handle(ARG32(0));
    ptr_t op = ARG32(1), gp = ARG32(2);
    h_ogg_packet hop;
    if (op) conv_packet(&hop, (const g_ogg_packet*)from_ptrv(op));
    R_EAX = (uint32_t)h_packetin(d ? d->dec : NULL, op ? &hop : NULL, gp ? (int64_t*)from_ptrv(gp) : NULL);
}

// int th_decode_ycbcr_out(th_dec_ctx*, th_ycbcr_buffer)
static void w_th_decode_ycbcr_out(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    theora_dec_t* d = dec_from_handle(ARG32(0));
    g_th_img_plane* gb = (g_th_img_plane*)from_ptrv(ARG32(1));
    h_th_img_plane hb[3];
    int ret = h_ycbcr_out(d ? d->dec : NULL, hb);
    if (ret || !d || !gb) { R_EAX = (uint32_t)ret; return; }
    size_t need = 0;
    for (int i = 0; i < 3; ++i) need += (size_t)hb[i].width * hb[i].height;
    if (need > d->lowsz) {
        if (d->low) box32_free(d->low);
        d->low = box32_malloc(need);
        d->lowsz = d->low ? need : 0;
        if (!d->low) { R_EAX = (uint32_t)-1; return; }
    }
    uint8_t* dst = d->low;
    for (int i = 0; i < 3; ++i) {
        const int w = hb[i].width, h = hb[i].height;
        const uint8_t* src = hb[i].data;
        for (int row = 0; row < h; ++row)
            memcpy(dst + (size_t)row * w, src + (ptrdiff_t)row * hb[i].stride, w);
        gb[i].width = w;
        gb[i].height = h;
        gb[i].stride = w;
        gb[i].data = to_ptrv(dst);
        dst += (size_t)w * h;
    }
    R_EAX = 0;
}

// ogg_int64_t th_granule_frame(void* encdec, ogg_int64_t granpos)
static void w_th_granule_frame(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    theora_dec_t* d = dec_from_handle(ARG32(0));
    int64_t gp = from_ptri(int64_t, R_ESP + 8);
    gh_ui64_t r;
    r.i = h_granule_frame(d ? d->dec : NULL, gp);
    R_EAX = r.d[0];
    R_EDX = r.d[1];
}

// double th_granule_time(void* encdec, ogg_int64_t granpos)
static void w_th_granule_time(x64emu_t* emu, uintptr_t fnc)
{
    (void)fnc;
    theora_dec_t* d = dec_from_handle(ARG32(0));
    int64_t gp = from_ptri(int64_t, R_ESP + 8);
    double r = h_granule_time(d ? d->dec : NULL, gp);
    fpu_do_push(emu);
    ST0.d = r;
}

static int setup_theora(void)
{
    static int done = 0, ok = 0;
    if (done) return ok;
    done = 1;
    void* lib = dlopen("libtheoradec.so.1", RTLD_NOW | RTLD_LOCAL);
    if (!lib) {
        printf_log(LOG_INFO, "Game hook: native libtheoradec.so.1 not found, libtheora not hooked\n");
        return 0;
    }
#define GO(V, S) V = dlsym(lib, S); if (!V) return 0;
    GO(h_headerin, "th_decode_headerin")
    GO(h_alloc, "th_decode_alloc")
    GO(h_free, "th_decode_free")
    GO(h_ctl, "th_decode_ctl")
    GO(h_packetin, "th_decode_packetin")
    GO(h_ycbcr_out, "th_decode_ycbcr_out")
    GO(h_setup_free, "th_setup_free")
    GO(h_granule_frame, "th_granule_frame")
    GO(h_granule_time, "th_granule_time")
    GO(h_comment_init, "th_comment_init")
    GO(h_comment_clear, "th_comment_clear")
#undef GO
    ok = 1;
    return 1;
}

typedef struct gamehook32_s {
    const char* symbol;
    uint32_t size;
    uint64_t hash;
    void* native;
    wrapper_t wrapper;
    int (*setup)(void);   // per group: returns 0 if the native side isn't available
    int group;            // all hooks of a group are installed together, or none
} gamehook32_t;

static int setup_decodeRGBX(void)
{
    tG_V = from_ptrv(0xb280054);
    tG_U = from_ptrv(0xb280454);
    tR_V = from_ptrv(0xb280854);
    tB_U = from_ptrv(0xb280c54);
    tY = from_ptrv(0xb281054);
    return 1;
}

// Grim Fandango Remastered (GOG Linux 2.3.0.7)
static const gamehook32_t gamehooks32[] = {
    { "decodeRGBX",          0x2c0,  0xd093c74f420945f9ULL, native_decodeRGBX, vFp_32,                setup_decodeRGBX, 1 },
    { "th_decode_headerin",  0x7d4,  0xdd267bf0a3193e4aULL, NULL,              w_th_decode_headerin,  setup_theora,     2 },
    { "th_decode_alloc",     0x2ec,  0xc33ba7a8094a1deaULL, NULL,              w_th_decode_alloc,     setup_theora,     2 },
    { "th_decode_free",      0x68,   0x58a79757982eb00aULL, NULL,              w_th_decode_free,      setup_theora,     2 },
    { "th_decode_ctl",       0x151,  0xc8cfdfa3b2885727ULL, NULL,              w_th_decode_ctl,       setup_theora,     2 },
    { "th_decode_packetin",  0x3d84, 0xbd9e7c86947fb338ULL, NULL,              w_th_decode_packetin,  setup_theora,     2 },
    { "th_decode_ycbcr_out", 0x30,   0x7faf9ea149635fbdULL, NULL,              w_th_decode_ycbcr_out, setup_theora,     2 },
    { "th_setup_free",       0x30,   0x5931ba5cb78a0f63ULL, NULL,              w_th_setup_free,       setup_theora,     2 },
    { "th_granule_frame",    0xba,   0xb58b6907a9aca109ULL, NULL,              w_th_granule_frame,    setup_theora,     2 },
    { "th_granule_time",     0x120,  0xafe1c990d39d06f6ULL, NULL,              w_th_granule_time,     setup_theora,     2 },
};
#define N_GAMEHOOKS32 (sizeof(gamehooks32) / sizeof(gamehooks32[0]))

void InstallGameHooks32(elfheader_t* h)
{
    if (!BOX64ENV(gamehooks) || !h)
        return;
    uintptr_t starts[N_GAMEHOOKS32] = { 0 };
    int bad_group[8] = { 0 }, seen_group[8] = { 0 };
    // pass 1: every hook of a group must match the known build
    for (size_t i = 0; i < N_GAMEHOOKS32; ++i) {
        const gamehook32_t* g = &gamehooks32[i];
        uintptr_t end = 0;
        if (!ElfGetSymTabStartEnd32(h, &starts[i], &end, g->symbol)) {
            bad_group[g->group] = 1;
            continue;
        }
        seen_group[g->group] = 1;
        if (end - starts[i] != g->size || fnv1a64((const uint8_t*)starts[i], g->size) != g->hash) {
            printf_log(LOG_INFO, "Game hook: %s found at %p but doesn't match the known build\n", g->symbol, (void*)starts[i]);
            bad_group[g->group] = 1;
        }
    }
    // pass 2: native side available?
    for (size_t i = 0; i < N_GAMEHOOKS32; ++i) {
        const gamehook32_t* g = &gamehooks32[i];
        if (seen_group[g->group] && !bad_group[g->group] && g->setup && !g->setup())
            bad_group[g->group] = 1;
    }
    // pass 3: install
    for (size_t i = 0; i < N_GAMEHOOKS32; ++i) {
        const gamehook32_t* g = &gamehooks32[i];
        if (!seen_group[g->group] || bad_group[g->group])
            continue;
        // the native pointers of the theora group are only known after setup: use the wrapper as the bridge key
        uintptr_t bridge = AddBridge(my_context->system, g->wrapper, g->native ? g->native : (void*)g->wrapper, 0, g->symbol);
        addAlternate((void*)starts[i], (void*)bridge);
        printf_log(LOG_INFO, "Game hook: %s at %p redirected to native code\n", g->symbol, (void*)starts[i]);
    }
}
