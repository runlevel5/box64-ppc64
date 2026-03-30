## Four-Backend Native Flag System Comparison

box64 supports four dynarec backends. They use **two fundamentally different models** for native flag optimization:

- **Propagation model** (ARM64 only): Hardware condition flags persist across instructions. The dynarec tracks flag liveness and skips materialization when native flags are still valid.
- **Fusion model** (PPC64LE, LA64, RV64): No persistent condition flags. The dynarec saves operands at the flag producer and re-evaluates the condition at the consumer using native compare-and-branch instructions.

### Architecture Summary

| Aspect | ARM64 | PPC64LE | LA64 (LoongArch64) | RV64 (RISC-V 64) |
|--------|-------|---------|---------------------|-------------------|
| **Hardware flags** | Global NZCV register (N, Z, C, V) | 8 CR fields + XER (CA, SO) | None | None |
| **Flag-setting insns** | ADDS/SUBS/ANDS (implicit) | CMP/CMPL (explicit only) | None | None |
| **Extra HW acceleration** | — | — | Optional LBT extension (x86 eflags in hardware) | — |
| **Model** | Propagation (forward) | Fusion (backward) | Fusion (backward) | Fusion (backward) |
| **SETFLAGS signature** | `(A, B)` — 2 params | `(A, B, FUSION)` — 3 params | `(A, B, FUSION)` — 3 params | `(A, B, FUSION)` — 3 params |
| **Analysis functions** | `updateNativeFlags` + `propagateNativeFlags` + `getNativeFlagsUsed` + `mark_natflag` | `updateNativeFlags` only | `updateNativeFlags` only | `updateNativeFlags` only |
| **Pass 0 macros** | `FEMIT`, `IFNATIVE`, `IFXNATIVE` | `READFLAGS_FUSION`, `NAT_FLAGS_OPS` | Same as PPC64LE | Same as PPC64LE |
| **Branch mechanism** | `Bcc` on hardware NZCV | `CMPD(op1,op2)` + `Bcond` | Compare-and-branch: `BEQ/BLT/BLTU(r1,r2,off)` | Compare-and-branch: `BEQ/BLT/BLTU(r1,r2,off)` |
| **Per-insn metadata** | 12 fields (bitmask-based) | 9 fields (boolean + registers) | 9 fields (identical to PPC64LE + `nat_flags_sf`) | 8 fields (same as PPC64LE, no `nat_flags_sf`) |
| **NATIVEJUMP** | N/A (uses `Bcc` directly) | `CMPD_ZR + Bcond + NOP` (3 insns) | Compare-and-branch (1-2 insns) | Compare-and-branch (1-2 insns) |
| **NATIVESET (SETcc)** | Implemented | Implemented (`CMP + MFCR + RLWINM`) | Implemented | Implemented |
| **NATIVEMV (CMOVcc)** | Implemented | **Implemented (ISEL)** | Implemented | Implemented |

### Key Insight

LA64 and RV64 are essentially what PPC64LE's fusion model is adaopted from. All three share identical per-instruction struct fields, the same `updateNativeFlags()` backward-walk algorithm, the same `NAT_FLAGS_OPS` / `NATIVEJUMP` / `NATIVESET` macro patterns, and the same `READFLAGS_FUSION` pass-0 logic.

This means **the fusion model is the correct architectural fit for PPC64LE** — not ARM64's propagation model. ARM64 propagation is motivated by hardware NZCV persistence, which PPC64LE (and LA64/RV64) lack.

**The remaining gaps in PPC64LE's fusion coverage**:
1. ~~**NATIVEMV is unimplemented**~~ — ✅ DONE (commit `5b7626078`, ISEL-based)
2. ~~**NAT_FLAGS_ENABLE_SF is dead code**~~ — ✅ DONE (commit `271f4e111`, called in 24 emit functions)
3. **No 8/16-bit fusion** — LA64 handles some via sign/zero extension
4. **ADD/SUB carry fusion** — ~~SUB carry~~ ✅ DONE; ADD carry still pending (see Gap 2)

---

## ARM64: Propagation Model (Detailed)

### How It Works

1. **Pass 0**: `FEMIT()` marks flag-setting ARM64 instructions as `NAT_FLAG_OP_TOUCH`. `IFNATIVE`/`IFXNATIVE` calls `mark_natflag()` to register which native flags (NF_EQ, NF_SF, NF_VF, NF_CF) are produced or consumed.
2. **Between passes**: `updateNativeFlags()` → `propagateNativeFlags()` → `getNativeFlagsUsed()` forward-scans from each flag-setter to determine which native flags survive to which consumers.
3. **Passes 2-3**: `IFNATIVE(NF_xx) {} else { materialize }` — skips materialization when native flags are still live. `GOCOND` uses ARM64 condition codes directly (`cEQ`, `cNE`, `cCS`, `cCC`, `cMI`, `cPL`, `cVS`, `cVC`, `cHI`, `cLS`, `cGE`, `cLT`, `cGT`, `cLE`).

### Per-Instruction Metadata (dynarec_arm64_private.h)

```c
uint8_t set_nat_flags;          // bitmask: NF_EQ|NF_SF|NF_VF|NF_CF this insn can produce
uint8_t use_nat_flags;          // bitmask: which native flags this insn consumes (after main op)
uint8_t use_nat_flags_before;   // consumed BEFORE main op (e.g., ADC reads carry first)
uint8_t nat_flags_op:4;         // enum: NONE / TOUCH / UNUSABLE / CANCELED
uint8_t nat_flags_op_before:4;  // same for "before" phase
uint8_t before_nat_flags;       // propagated: native flags available before this opcode
uint8_t need_nat_flags;         // FINAL result: which native flags to expect from producer
uint8_t gen_inverted_carry:1;   // producer generates ARM64's inverted carry (SUB/CMP)
uint8_t normal_carry:1;         // consumer expects normal carry
uint8_t normal_carry_before:1;  // same for "before" phase
uint8_t invert_carry:1;         // consumer needs carry inversion
```

NF_* constants: `NF_EQ=1`, `NF_SF=2`, `NF_VF=4`, `NF_CF=8`.

### Analysis Pipeline (dynarec_arm64_functions.c)

- **`mark_natflag()`** (lines 978-992): Registers flag interest during pass 0. Adds to `set_nat_flags` or `use_nat_flags`.
- **`flag2native()`** (lines 994-1006): Maps x86 flags → native: X_ZF→NF_EQ, X_SF→NF_SF, X_OF→NF_VF, X_CF→NF_CF. Returns 0 for X_AF/X_PF.
- **`getNativeFlagsUsed()`** (lines 1014-1096): Forward-walks from a producer to determine which native flags are consumed. Aborts if: `has_callret`, `nat_flags_op_before` set, partial flag overwrite, or incompatible usage.
- **`propagateNativeFlags()`** (lines 1098-1148): Forward-scans from a producer. Computes `flags = set_nat_flags & flag2native(need_after)`, calls `getNativeFlagsUsed()`, then walks forward marking `need_nat_flags |= used_flags` on each instruction.
- **`updateNativeFlags()`** (lines 1150-1159): Entry point. For each instruction with `gen_flags != 0` AND `nat_flags_op == TOUCH`, calls `propagateNativeFlags()`.

### Emit Function Pattern

```c
// emit_add32 (dynarec_arm64_emit_math.c)
IFX(X_ALL) { ADDSxw(s1, s1, s2); }    // flag-setting ADDS
else        { ADDxw(s1, s1, s2);  }    // non-flag ADD

IFX(X_ZF) {
    IFNATIVE(NF_EQ) { /* empty — ADDS already set Z */ }
    else { CSETw(s4, cEQ); BFIw(xFlags, s4, F_ZF, 1); }
}
IFX(X_CF) {
    IFNATIVE(NF_CF) { /* empty — ADDS already set C */ }
    else { CSETw(s4, cCS); BFIw(xFlags, s4, F_CF, 1); }
}
// ... same for SF (NF_SF), OF (NF_VF)
```

When native flags are live: the `IFNATIVE` block is empty — zero instructions emitted.
When not live: extract via CSET and insert into xFlags.

### Carry Inversion

ARM64 SUBS sets C=1 on no-borrow (opposite of x86). `GEN_INVERTED_CARRY()` marks the producer, and downstream consumers check `invert_carry` to apply `CSINV`.

---

## LA64: Fusion Model + LBT Extension (Detailed)

### Architecture

LoongArch64 has **no global flags register** and **no flag-setting instruction variants**. Arithmetic instructions never set condition codes. Instead, the ISA provides:

- **Compare-and-branch**: `BEQ/BNE/BLT/BGE/BLTU/BGEU rj, rd, offset` — compare two registers and branch directly
- **Set-on-condition**: `SLT/SLTU rd, rj, rk` + synthetic forms (SEQ, SNE, SGE, SGEU, SGT, SLE, SGTU, SLEU)
- **LBT extension** (hardware x86 emulation): Provides a separate `LBT4.eflags` register and instructions like `X64_ADD_W/D`, `X64_SUB_W/D`, `X64_AND_W/D` that compute x86 flags in hardware. `X64_SETJ(rd, condition)` reads these hardware eflags.

### Per-Instruction Metadata (dynarec_la64_private.h, lines 114-128)

Identical to PPC64LE plus `nat_flags_sf`:

```c
uint8_t nat_flags_fusion:1;     // participates in fusion
uint8_t nat_flags_nofusion:1;   // fusion blocked
uint8_t nat_flags_carry:1;      // producer supports carry conditions
uint8_t nat_flags_sign:1;       // producer supports sign conditions
uint8_t nat_flags_sf:1;         // producer supports SF-only conditions
uint8_t nat_flags_needsign:1;   // consumer needs signed comparison
uint8_t no_scratch_usage:1;     // transparent to fusion (can be "seen through")
uint8_t nat_flags_op1;          // saved operand 1
uint8_t nat_flags_op2;          // saved operand 2
uint16_t nat_next_inst;         // consumer instruction index
```

### How It Works

Same fusion model as PPC64LE:

1. **Pass 0**: `SETFLAGS(A, B, FUSION)` marks producers. `READFLAGS_FUSION(A, ...)` tentatively marks consumers. Note: LA64 does NOT check `dynarec_test` — fusion stays active even in test mode.
2. **Between passes**: `updateNativeFlags()` (lines 815-843) validates backward from consumer to producer. Same algorithm as PPC64LE.
3. **Passes 2-3**: Producer calls `NAT_FLAGS_OPS(op1, op2, s1, s2)`. Consumer uses `NATIVEJUMP_safe(COND, target)` which expands to a LoongArch compare-and-branch instruction.

### Three-Tier Condition Evaluation

LA64 uniquely has three code paths in `GOCOND` (lines 1619-1697):

1. **Native fusion** (`nat_flags_fusion == 1`): `NATIVEJUMP` / `NATIVESET` / `NATIVEMV` using stored operands — no flag register access
2. **LBT hardware** (`cpuext.lbt == 1`): `X64_SETJ(tmp, condition)` → `BEQZ`/`BNEZ` — reads hardware x86 eflags
3. **Software fallback**: Extract bits from emulated `xFlags` register via shifts/ANDI

### Emit Function Pattern

```c
// emit_cmp32 (dynarec_la64_emit_tests.c)
NAT_FLAGS_ENABLE_CARRY();     // enable carry fusion
NAT_FLAGS_ENABLE_SIGN();      // enable sign fusion
// ... compute flags (LBT or manual) ...
if(rex.w) {
    NAT_FLAGS_OPS(s1, s2, s3, s4);      // 64-bit: pass original operands
} else if(nat_flags_needsign) {
    SEXT_W(s3, s1); SEXT_W(s4, s2);     // 32-bit signed: sign-extend
    NAT_FLAGS_OPS(s3, s4, s5, xZR);
} else {
    ZEROUP2(s3, s1); ZEROUP2(s4, s2);    // 32-bit unsigned: zero-extend
    NAT_FLAGS_OPS(s3, s4, s5, xZR);
}
```

For ADD/SUB/AND/OR/XOR, operands are `(result, xZR)` — consumer uses `BEQ/BNE result, zero` for ZF, `BLT/BGE result, zero` for SF.

### NATIVEMV — Implemented

LA64 implements conditional move macros (`MVLTU_`, `MVGEU_`, `MVNE_`, `MVEQ_`, etc.) using branch-over-move patterns or LoongArch's `MASKEQZ`/`MASKNEZ` + `OR` sequences. PPC64LE now also has NATIVEMV implemented using ISEL (commit `5b7626078`).

---

## RV64: Fusion Model (Detailed)

### Architecture

RISC-V 64 has **no global flags register** and **no flag-setting instruction variants**. Condition testing uses:

- **Compare-and-branch**: `BEQ/BNE/BLT/BGE/BLTU/BGEU rs1, rs2, offset`
- **Set-on-condition**: `SLT/SLTU rd, rs1, rs2` + pseudo-instructions (SEQZ, SNEZ, SGT, etc.)
- No LBT or any hardware x86 acceleration

### Per-Instruction Metadata (dynarec_rv64_private.h, lines 125-135)

Nearly identical to PPC64LE but **without `nat_flags_sf`**:

```c
uint8_t nat_flags_fusion:1;     // participates in fusion
uint8_t nat_flags_nofusion:1;   // fusion blocked
uint8_t nat_flags_carry:1;      // supports carry conditions
uint8_t nat_flags_sign:1;       // supports sign conditions
uint8_t nat_flags_needsign:1;   // consumer needs signed comparison
uint8_t nat_flags_op1;          // saved operand 1
uint8_t nat_flags_op2;          // saved operand 2
uint16_t nat_next_inst;         // consumer instruction index
```

Missing vs LA64/PPC64LE: no `nat_flags_sf` field. This means RV64 cannot distinguish "SF-only" fusion (JS/JNS) from "sign+overflow" fusion (JL/JGE). In practice, JS/JNS fusion requires both `nat_flags_sign` set.

### How It Works

Same fusion model as PPC64LE/LA64:

1. **Pass 0**: `SETFLAGS(A, B, FUSION)` + `READFLAGS_FUSION(A, ...)` — same logic.
2. **Between passes**: `updateNativeFlags()` (lines 835-863) — same backward-walk algorithm.
3. **Passes 2-3**: `NAT_FLAGS_OPS` stores operands → `NATIVEJUMP_safe` emits RISC-V compare-and-branch.

### Two-Tier Condition Evaluation

RV64 has only two code paths (no LBT):

1. **Native fusion** (`nat_flags_fusion == 1`): `NATIVEJUMP` / `NATIVESET` / `NATIVEMV` using stored operands
2. **Software fallback**: Extract bits from `xFlags` register

### Emit Function Pattern

Same as LA64 minus LBT path:

```c
// emit_cmp32 (dynarec_rv64_emit_tests.c)
NAT_FLAGS_ENABLE_CARRY();
NAT_FLAGS_ENABLE_SIGN();
// ... compute flags manually ...
// 32-bit with sign needed: sign-extend operands
// 32-bit without sign: zero-extend operands
NAT_FLAGS_OPS(s1, s2, s3, s4);
```

### NATIVEMV — Implemented

RV64 implements conditional move macros using branch-over-move patterns: `CMPD(op1,op2) + inverted_Bcond(skip) + MV(rd,rs) + skip:`. This gives PPC64LE a clear reference implementation.

---

## Condition Coverage (All Backends)

| x86 Condition | ARM64 | PPC64LE | LA64 | RV64 | Notes |
|--------------|-------|---------|------|------|-------|
| JO / JNO | YES (NF_VF) | **NO** | **NO** | **NO** | Only ARM64 has overflow in NZCV |
| JC / JNC | YES (NF_CF) | YES (GEU/LTU) | YES (GEU/LTU) | YES (GEU/LTU) | All fusion backends use unsigned compare |
| JZ / JNZ | YES (NF_EQ) | YES (NE/EQ) | YES (NE/EQ) | YES (NE/EQ) | Universal support |
| JBE / JA | YES (NF_EQ+NF_CF) | YES (GTU/LEU) | YES (GTU/LEU) | YES (GTU/LEU) | All fusion backends handle compound |
| JS / JNS | YES (NF_SF) | YES* (GE/LT) | YES* (GE/LT) | YES* (GE/LT) | *Requires nat_flags_sign; PPC64LE also enables via NAT_FLAGS_ENABLE_SF for arithmetic |
| JP / JNP | **NO** | **NO** | **NO** | **NO** | No backend has hardware parity |
| JL / JGE | YES (NF_SF+NF_VF) | YES (GE/LT) | YES (GE/LT) | YES (GE/LT) | All use signed compare |
| JLE / JG | YES (NF_SF+NF_VF+NF_EQ) | YES (GT/LE) | YES (GT/LE) | YES (GT/LE) | All use signed compare |
| **Score** | **14/16** | **12/16** | **12/16** | **12/16** | Same theoretical coverage |

### Producer Coverage (Which Instructions Enable Fusion)

| Producer | ARM64 | PPC64LE | LA64 | RV64 |
|----------|-------|---------|------|------|
| CMP 32/64 | Full (NF_EQ+SF+VF+CF) | Full (ZF+CF+sign) | Full (ZF+CF+sign) | Full (ZF+CF+sign) |
| TEST 32/64 | Full | Full | Full | Full |
| ADD 32/64 | Full | ZF+SF | ZF only | ZF only |
| SUB 32/64 | Full | ZF+SF+CF | ZF only | ZF only |
| AND/OR/XOR 32/64 | Full (NF_EQ+SF) | ZF+SF | ZF only | ZF only |
| NEG/INC/DEC 32/64 | Full | ZF+SF | ZF only | ZF only |
| ADC/SBB 32/64 | Partial | ZF+SF | ZF only | ZF only |
| Shifts | Partial (NF_EQ+SF) | ZF+SF | ZF only | ZF only |
| 8/16-bit ops | Limited | **None** | Some (via ext) | **None** |

### Consumer Coverage (Which Operations Use Fusion)

| Consumer | ARM64 | PPC64LE | LA64 | RV64 |
|----------|-------|---------|------|------|
| Jcc (branch) | All via NZCV | NATIVEJUMP | NATIVEJUMP | NATIVEJUMP |
| SETcc | Via CSET | NATIVESET (wired) | NATIVESET | NATIVESET |
| CMOVcc | Via CSEL | **NATIVEMV (ISEL)** | NATIVEMV | NATIVEMV |

### Instruction Count Impact (CMP rax, rbx; JZ target)

| Scenario | ARM64 | PPC64LE | LA64 | RV64 |
|----------|-------|---------|------|------|
| No native flags | ~10-15 | ~10-15 | ~10-15 | ~10-15 |
| Native/fused | ~2 (SUBS + Bcond) | ~5 (MV + CMPD + BEQ + NOP) | ~1 (BEQ op1, op2, tgt) | ~1 (BEQ op1, op2, tgt) |

Note: LA64 and RV64 achieve better fused instruction counts than PPC64LE because their ISAs have direct compare-and-branch instructions (1 insn), while PPC64LE requires separate CMP + Bcond (2-3 insns). This is a hardware limitation, not a software deficiency.

---

## PPC64LE Fusion Gaps to Address

### Gap 1: Implement NATIVEMV for CMOVcc — ✅ DONE
- **Implemented:** Commit `5b7626078` replaced all 11 `MV##COND##_` NOP stubs with branchless ISEL-based conditional moves.
- **Pattern:** `CMPD_ZR(op1, op2)` + `ISEL(dst, src, dst, BI(cr, bit))` (2 insns, 8 bytes). Inverted conditions swap RA/RB in ISEL.
- **CMOVcc handler** in `_0f.c` updated: MODREG path uses `NATIVEMV(NATYES, gd, ed)` instead of branch-over-move (saves 1 insn/4 bytes per CMOVcc).
- **Tested:** `test_cmovcc_fusion` 64/64 PASS, zero regressions across 42/52 NASM tests and 16/34 ctest.

### Gap 2: ADD/SUB Carry Fusion (JC/JNC after ADD/SUB)

#### SUB Carry Fusion — ✅ DONE
- **Implementation:** Added `nat_flags_needcarry` field to `instruction_ppc64le_t` and `NAT_FLAGS_ENABLE_CARRY()` calls to all 5 SUB emit functions (emit_sub8, emit_sub16, emit_sub32, emit_sub32c, emit_sub8c/sub16 forwarding).
- **Mechanism:** Before the SUB instruction, when carry fusion is active (`nat_flags_fusion && nat_flags_needcarry`), save op1 into scratch register s6 via `MV(s6, s1)`. Then in the fusion block, 3-way dispatch:
  1. **needcarry** → `NAT_FLAGS_OPS(saved_op1, op2, ...)` — passes original operands for unsigned CMPLD at branch site
  2. **needsign** → sign-extend result, `NAT_FLAGS_OPS(result, xZR, ...)`
  3. **else** → zero-extend result, `NAT_FLAGS_OPS(result, xZR, ...)`
- **Key insight:** Carry and needsign are mutually exclusive (carry consumers use X_CF or X_CF|X_ZF, never X_SF). For SUB, carry = (op1 < op2) in unsigned terms, which maps directly to CMPLD(op1, op2) at the branch site.
- **updateNativeFlags():** Extended to set `nat_flags_needcarry` on producer when consumer requests X_CF. The backward walk validates fusion eligibility including the new carry path.
- **emit_sub32c special case:** When using the ADDI fast path (small constant), s2 doesn't hold the constant value. Added guard to materialize constant into s2 when carry fusion is active.
- **Tests:** `test_sub_carry_fusion.asm` — 40 sub-tests covering sub8/16/32/64 → ADC/SBB with CF=1 and CF=0, immediate paths, chained SUBs, ZF non-regression.

#### ADD Carry Fusion — ✅ DONE
- **Implementation:** Added `NAT_FLAGS_ENABLE_CARRY()` calls and 3-way fusion dispatch to all 5 ADD emit functions (emit_add8, emit_add16, emit_add32, emit_add32c, emit_add8c).
- **Mechanism:** Before the ADD instruction, when carry fusion is active (`nat_flags_fusion && nat_flags_needcarry`), save op1 into scratch register s6 via `MV(s6, s1)`. Then in the fusion block, 3-way dispatch:
  1. **needcarry** → `NAT_FLAGS_OPS(result, saved_op1, ...)` — passes result and original op1 for unsigned CMPLD at branch site
  2. **needsign** → sign-extend result, `NAT_FLAGS_OPS(result, xZR, ...)`
  3. **else** → zero-extend result, `NAT_FLAGS_OPS(result, xZR, ...)`
- **Key difference from SUB:** ADD carry = (result < op1) in unsigned terms, so `NAT_FLAGS_OPS(result, saved_op1)`. SUB carry = (op1 < op2), so `NAT_FLAGS_OPS(saved_op1, op2)`. This is why ADD saves op1 pre-ADD and compares against the result, while SUB saves op1 and compares against op2.
- **emit_add32c:** No extra constant materialization needed (unlike emit_sub32c). Since ADD carry compares result vs saved_op1 (not op1 vs op2), s2 is not needed in the carry path.
- **Signatures:** All 5 emit_add functions gained an `int s6` parameter (29 call sites updated across 7 files).
- **Tests:** `test_add_carry_fusion.asm` — 45 sub-tests covering add8/16/32/64 → ADC/SBB with CF=1 and CF=0, add8c/add32c immediate paths (small + large constants), chained ADDs, ZF non-regression, multi-flag verification (CF+ZF+SF).

### Gap 3: Wire Up NATIVESET for SETcc — ✅ ALREADY DONE
- **Current state:** NATIVESET is fully wired into SETcc handlers (0x90-0x9F) in `_0f.c` lines 1024-1049. The `GOCOND` SETcc expansion checks `nat_flags_fusion` and calls `NATIVESET(NATYES, tmp3)` for the fusion path, falling back to xFlags extraction otherwise.
- **Supported conditions:** All except JO/JNO and JP/JNP (same as NATIVEJUMP/NATIVEMV).
- **No action needed.**

### Gap 4: Enable NAT_FLAGS_ENABLE_SF for JS/JNS — ✅ ALREADY DONE
- **Current state:** `NAT_FLAGS_ENABLE_SF()` is called in all 24 arithmetic emit functions (Phase 2 SF fusion, commit `271f4e111`). `NAT_FLAGS_ENABLE_SIGN()` and `NAT_FLAGS_ENABLE_CARRY()` are called in CMP/TEST emit functions.
- **CMP/TEST:** Fully enabled — both SIGN and CARRY fusion active.
- **ADD/SUB/NEG/INC/DEC/ADC/SBB:** SF fusion enabled via `NAT_FLAGS_ENABLE_SF()`.
- **No action needed.**

### Gap 5: Support JO/JNO (Overflow)
- **Current state:** JO/JNO always fall back to xFlags extraction. Same limitation on LA64 and RV64.
- **Challenge:** PPC64LE CMP doesn't set overflow. Overflow is set by arithmetic instructions (add./subf./etc. with OE=1) which set XER[SO], not CR0.
- **Options:**
  a. Use PPC64LE `addo./subfo.` (with OE=1) which sets XER[SO] — but this is a different register, not CR0
  b. Compute overflow manually at the branch site from saved operands + result
  c. Save the result along with operands (3-register fusion variant)
- **Difficulty:** HIGH — requires architectural extension to the fusion model. No other fusion backend solves this either.

---

## Key Files Reference

### PPC64LE

| File | Purpose |
|------|---------|
| `src/dynarec/ppc64le/dynarec_ppc64le_private.h` | instruction_ppc64le_t struct with nat_flags fields (lines 128-136, 143) |
| `src/dynarec/ppc64le/dynarec_ppc64le_helper.h` | NAT_FLAGS_OPS (823-835), GOCOND (1896-1974), Bcond_safe (1536-1664), NATIVESET (1848), NATIVEMV (1851), S##COND macros (1744-1826), MV##COND macros (2483-2552, ISEL-based) |
| `src/dynarec/ppc64le/dynarec_ppc64le_functions.c` | updateNativeFlags() (448-476), get_free_scratch() (478-495) |
| `src/dynarec/ppc64le/dynarec_ppc64le_pass0.h` | READFLAGS_FUSION (17-33), SETFLAGS (34-47), SCRATCH_USAGE (94-97) |
| `src/dynarec/ppc64le/dynarec_ppc64le_emit_math.c` | All emit_* functions |
| `src/dynarec/ppc64le/dynarec_ppc64le_emit_tests.c` | emit_cmp*/emit_test* functions |

### ARM64 (Reference)

| File | Purpose |
|------|---------|
| `src/dynarec/arm64/dynarec_arm64_private.h` | instruction_arm64_t (lines 127-137), NF_* constants (13-16) |
| `src/dynarec/arm64/dynarec_arm64_functions.c` | updateNativeFlags (1150-1159), propagateNativeFlags (1098-1148), getNativeFlagsUsed (1014-1096), mark_natflag (978-992), flag2native (994-1006) |
| `src/dynarec/arm64/dynarec_arm64_helper.h` | GOCOND (1663-1817), IFNATIVE macros (804-808) |
| `src/dynarec/arm64/dynarec_arm64_pass0.h` | FEMIT (line 48), IFNATIVE (line 49), IFXNATIVE (line 59), INST_EPILOG (lines 31-36) |
| `src/dynarec/arm64/dynarec_arm64_emit_math.c` | emit_add32 (23-78), emit_sub32 (160-218) — IFNATIVE usage pattern |

### LA64 (Reference)

| File | Purpose |
|------|---------|
| `src/dynarec/la64/dynarec_la64_private.h` | instruction_la64_t (lines 91-132), nat_flags fields (114-128) |
| `src/dynarec/la64/dynarec_la64_functions.c` | updateNativeFlags() (815-843), get_free_scratch() (845-862) |
| `src/dynarec/la64/dynarec_la64_helper.h` | NAT_FLAGS_OPS (975-987), GOCOND (1619-1697), NATIVEJUMP/SET/MV (1705-1715) |
| `src/dynarec/la64/dynarec_la64_pass0.h` | READFLAGS_FUSION (18-34), SETFLAGS (36-49) |
| `src/dynarec/la64/dynarec_la64_emit_tests.c` | emit_cmp32 (271-351) — NAT_FLAGS_ENABLE_CARRY/SIGN pattern |
| `src/dynarec/la64/dynarec_la64_emit_math.c` | emit_add32 (24-119) — LBT vs software dual path |

### RV64 (Reference)

| File | Purpose |
|------|---------|
| `src/dynarec/rv64/dynarec_rv64_private.h` | instruction_rv64_t (lines 125-135), nat_flags fields |
| `src/dynarec/rv64/dynarec_rv64_functions.c` | updateNativeFlags() (835-863), get_free_scratch() (865-881) |
| `src/dynarec/rv64/dynarec_rv64_helper.h` | NAT_FLAGS_OPS (1046-1058), GOCOND (1714-1792), NATIVEJUMP/SET/MV (1800-1810) |
| `src/dynarec/rv64/dynarec_rv64_pass0.h` | READFLAGS_FUSION (17-31), SETFLAGS (33-38) |
| `src/dynarec/rv64/dynarec_rv64_emit_tests.c` | emit_cmp32 (237-252) — NAT_FLAGS_ENABLE_CARRY/SIGN pattern |

### Common

| File | Purpose |
|------|---------|
| `src/include/regs.h` | F_SF=7, F_CF=0, F_ZF=6, F_OF=11, F_PF=2, F_AF=4 |
| `src/dynarec/dynarec_private.h` | X_CF, X_PF, X_AF, X_ZF, X_SF, X_OF constants; NAT_FLAGS_FUSION=0, NAT_FLAGS_NOFUSION=1 |
| `tests/dynarec/` | NASM test directory with run_dynarec_tests.sh and bin/ pre-built binaries |

---

## PPC64LE Fusion Implementation Details

### Per-instruction struct fields (dynarec_ppc64le_private.h)
```c
uint8_t nat_flags_fusion:1;    // line 128 - this instruction participates in fusion
uint8_t nat_flags_nofusion:1;  // line 129 - fusion explicitly blocked for this producer
uint8_t nat_flags_carry:1;     // line 130 - producer supports carry-based conditions
uint8_t nat_flags_sign:1;      // line 131 - producer supports sign-based conditions (JL/JGE/JLE/JG)
uint8_t nat_flags_sf:1;        // line 132 - producer supports SF-only conditions (JS/JNS)
uint8_t nat_flags_needsign:1;  // line 133 - consumer needs sign flag (set by updateNativeFlags)
uint8_t nat_flags_needcarry:1; // line 134 - consumer needs carry flag (set by updateNativeFlags)
uint8_t nat_flags_op1;         // line 136 - PPC64LE register holding first operand
uint8_t nat_flags_op2;         // line 137 - PPC64LE register holding second operand
uint16_t nat_next_inst;        // line 144 - instruction index of the consumer
```

### READFLAGS_FUSION (pass 0) -- lines 17-33 of dynarec_ppc64le_pass0.h
Fusion eligibility rules in pass 0:
- `X_ZF` alone: always eligible (all producers)
- `X_CF` or `X_CF|X_ZF`: only if producer has `nat_flags_carry`
- `X_SF|X_OF` or `X_SF|X_OF|X_ZF`: only if producer has `nat_flags_sign`
- `X_SF` alone: only if producer has both `nat_flags_sf` AND `nat_flags_sign`

### updateNativeFlags() -- lines 448-476 of dynarec_ppc64le_functions.c
Validates fusion by walking backward from consumer:
- Consumer must have exactly 1 predecessor = prev instruction
- Producer must set_flags covering all use_flags
- Can see through transparent instructions (no_scratch_usage, no flag set/use)
- If X_SF needed, sets nat_flags_needsign on producer
- If X_CF needed, sets nat_flags_needcarry on producer

### NAT_FLAGS_OPS (lines 823-835 of helper.h)
Stores op1/op2 register numbers into consumer's metadata. If next instruction is transparent (`no_scratch_usage`) and operands are GPRs, copies to scratch registers to prevent clobbering.

### GOCOND conditions and native mappings (lines 1896-1974 of helper.h)
Each GO() call: `GO(xFlags_extraction, non_taken, taken, native_non_taken, native_taken, flags_used, jmp_type)`
- JO/JNO: `_` (no native) -- always xFlags fallback
- JC/JNC: GEU/LTU (unsigned CMPLD)
- JZ/JNZ: NE/EQ
- JBE/JA: GTU/LEU
- JS/JNS: GE/LT (signed CMPD)
- JP/JNP: `_` (no native)
- JL/JGE: GE/LT
- JLE/JG: GT/LE

### Bcond_safe macros (lines 1536-1664 of helper.h)
Always 3 instructions: `CMPD_ZR(r1,r2) + Bcond + NOP` (near) or `CMPD_ZR(r1,r2) + inverted_Bcond + B` (far).
Signed: BEQ/BNE/BLT/BGE/BGT/BLE. Unsigned: BLTU/BGEU/BGTU/BLEU. Dead: B__ (3 NOPs).

### NATIVESET S-macros (lines 1744-1826 of helper.h)
Pattern: `CMPD_ZR(r1,r2) + MFCR(dst) + RLWINM(dst,dst,bit,31,31)` [+ XORI for inverted]
Implemented: SLT_, SGT_, SEQ_, SGE_, SLE_, SNE_, SLTU_, SGTU_, SGEU_, SLEU_, S__ (always 1).

### NATIVEMV macros (lines 2483-2552 of helper.h)
Implemented using ISEL instruction (commit `5b7626078`). Pattern: `CMPD_ZR/CMPLD_ZR(op1,op2) + ISEL(dst,src,dst,BI(cr,bit))`. Inverted conditions (NE, GE, LE, GEU, LEU) swap RA/RB operands in ISEL. All 11 macros: MVLT_, MVGE_, MVGT_, MVLE_, MVEQ_, MVNE_, MVLTU_, MVGEU_, MVGTU_, MVLEU_, MV__ (unconditional MR).

### IFXORNAT and IFX_PENDOR0 (lines 639-640 of helper.h)
- `IFXORNAT(A)`: execute if gen_flags needs A OR if fusion is active
- `IFX_PENDOR0`: execute if deferred flags pending OR (no gen_flags AND no fusion)

---

## Test Infrastructure

- **NASM dynarec tests:** 53 pre-built x86_64 ELF binaries in `tests/dynarec/bin/`
- **Test runner:** `tests/dynarec/run_dynarec_tests.sh`
- **Fusion-specific tests:** `test_jcc_fusion.asm` (89 tests), `test_setcc_fusion.asm` (77 tests), `test_cmovcc_fusion.asm` (64 tests), `test_sub_carry_fusion.asm` (40 tests)
- **ctest:** 34 tests on ppc64le-jit
- **Pre-existing failures (not caused by our changes):**
  - `test_32bit_*` (6 tests, 32-bit mode not supported)
  - `test_and_xor` (xor 64-bit REX.W -- both dynarec and interpreter fail)
  - `test_sse3_move` (rcpps/rsqrtps dynarec-only fail)
  - `test_sse_int` (packuswb -- both fail)
  - `test_sse_shuffle` (pshufb reverse -- both fail)
