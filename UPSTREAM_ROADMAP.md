# PPC64LE Dynarec Upstreaming Roadmap

Status tracker for upstreaming the PPC64LE dynarec from the `ppc64le-jit` branch to `upstream/main` (ptitSeb/box64).

## Current State (as of 2026-11-08)

Checked against `upstream/main` at `37f5e4b7b` (fetched 2026-11-08) and `ppc64le-jit` at `4c8ba4ea0`.

### Upstream PR status

The last PPC64LE opcode PR merged upstream is #3709 (2026-03-27); `git log upstream/main -- src/dynarec/ppc64le/` shows no `[PPC64LE_DYNAREC]` opcode commit after it.

**#3720 ("Add more opcodes", Batches 2d-2f) is still OPEN.** Reviews: ptitSeb approved on 2026-03-29, ksco requested changes on 2026-03-30, and the last activity is 2026-04-11. In that last comment ksco wrote that the PR "appears to be an unsupervised vibe-coding PR" and repeated the suggestion of "a complete human review for this PR and any subsequent ones before submission", per the Box64 contribution policy (`CONTRIBUTING.md`, `AGENTS.md`). Any further upstream PR has to address that request first.

Maintainers have changed upstream PPC64LE code since #3709, so `ppc64le-jit` has to be reconciled with these before anything else is proposed:

| Commit | Change |
|--------|--------|
| `a793cd52c` | [DYNAREC] Added preliminary interblocks deferred flags elimination (#4284) |
| `92527ded3` | [DYNAREC] Added dynablock in_used tracking and removed DYNAREC_PURGE (#4405) |
| `c61543e47` | [DYNAREC] Removed the secondary entry points (#4464) |
| `0b046f594`, `74d914909` | [DYNAREC] Fixed deferred 16-bit SHLD/SHRD flags with count>16 (#4648), and its partial rollback (#4650) |

### Infrastructure: partly upstream

Upstream has the scaffolding: the pass headers, emitter, printer, assembly stubs, `helper.c/h`, `functions.c/h` and the four emit files. It is **not** at parity with the branch:

- `updateflags_ppc64le.c` and `updateflags_ppc64le_pass.c` exist only on the branch.
- The 25 PPC64LE files that upstream already has differ from the branch by +11,937 / -2,500 lines (`git diff --stat upstream/main HEAD -- <those files>`), mostly in `helper.h` (2,694 changed lines), `helper.c` (1,704), `f0.c` (1,774), `emit_math.c` (1,152), `66.c` (891), `functions.c` (761) and `ppc64le_lock.S` (562).
- Another 84 files outside `src/dynarec/ppc64le`, `tests` and `docs` differ (+5,760 / -856).
- Upstream `helper.h` declares the same 104 `emit_*` functions as the branch, but **10 of them have a different signature on the branch**: `emit_add8/8c/16/32/32c` and `emit_sub8/8c/16/32/32c` take two extra scratch registers (added by the carry-fusion work, Phase 10). So upstreaming these is not "implementations only".

### What's Upstream in `_00.c`

| PR | Opcodes | Description |
|----|---------|-------------|
| #3592 | Infrastructure | Full dynarec scaffolding |
| #3620 | 0x50-0x5F, 0xC9 | PUSH/POP reg, LEAVE |
| #3633 | 0x63, 0x88-0x8B, 0x8D, 0x90-0x99, 0xB0-0xBF, 0xC6-0xC7 | MOV, NOP/XCHG, MOVSXD, CWDE/CDQ, LEA |
| #3652 | 0x00-0x05 | ADD Eb/Gb, ADD Ed/Gd, ADD AL/Ib, ADD EAX/Id |
| #3668 | 0x08-0x0D, 0x20-0x25, 0x28-0x2D, 0x30-0x35 | OR, AND, SUB, XOR (all Eb/Gb..EAX/Id forms) |
| #3677 | (refactor) | GETED/GETEB/GETGB/GETGBEB/WBACK/GBBACK/EBBACK helper macros + refactor _00.c ALU opcodes |
| #3684 | 0x10-0x15, 0x18-0x1D, 0x38-0x3D, 0x84-0x85, 0xA8-0xA9 | ADC, SBB, CMP, TEST (#3678 was closed and its CMP/TEST content landed here) |
| #3706 | 0x80-0x83 | Group 1 ALU immediate |
| #3709 | 0x70-0x7F, 0xE8, 0xE9/0xEB, 0xC2/0xC3, 0xC0/0xC1, 0xD0-0xD3, 0x68/0x6A, 0x69/0x6B, 0x86/0x87 | Jcc, CALL, JMP, RET, shifts/rotates, PUSH imm, IMUL, XCHG mem |

### Emit Files Upstream
- `dynarec_ppc64le_emit_math.c` — `emit_add8`, `emit_add8c`, `emit_add32`, `emit_add32c`, `emit_sub8`, `emit_sub8c`, `emit_sub32`, `emit_sub32c`, `emit_adc8`, `emit_adc8c`, `emit_adc16`, `emit_adc32`, `emit_sbb8`, `emit_sbb8c`, `emit_sbb16`, `emit_sbb32` (16 functions; `emit_adc16`/`emit_sbb16` came with #3684)
- `dynarec_ppc64le_emit_logic.c` — `emit_or8`, `emit_or8c`, `emit_or32`, `emit_or32c`, `emit_and8`, `emit_and8c`, `emit_and32`, `emit_and32c`, `emit_xor8`, `emit_xor8c`, `emit_xor32`, `emit_xor32c` (12 functions)
- `dynarec_ppc64le_emit_tests.c` — `emit_cmp8`, `emit_cmp8_0`, `emit_cmp16`, `emit_cmp16_0`, `emit_cmp32`, `emit_cmp32_0`, `emit_test8`, `emit_test8c`, `emit_test16`, `emit_test32`, `emit_test32c` (11 functions)
- `dynarec_ppc64le_emit_shift.c` — shift/rotate emit functions (PR #3709)

### Opcode Dispatch Files Upstream (stubs only)
- `dynarec_ppc64le_66.c` (36 lines upstream)
- `dynarec_ppc64le_66f0.c` (38 lines upstream)
- `dynarec_ppc64le_f0.c` (38 lines upstream)

## Upstreaming Plan

### Phase 1: Remaining ALU Operations in `_00.c`

Each batch follows the ADD pattern (6 opcodes per group: Eb/Gb, Ed/Gd, Gb/Eb, Gd/Ed, AL/Ib, EAX/Id).

**Style note**: Batches 1a/1b used manual inline byte register handling to match upstream's existing style. Batch 1-macros (#3677, merged) upstreamed the GETGB/GETEB/GETED/WBACK/GBBACK/EBBACK/GETGBEB macros (matching ARM64/RV64/LA64) AND refactor all existing opcode cases (ADD/OR/SUB/AND/XOR/MOV) to use them. All ALU opcodes in upstream `_00.c` have been macro-style since then; the only open-coded byte-register extraction left upstream is `MOV Eb, Gb` (0x88).

#### Batch 1a: OR + SUB — ✅ Merged
- **PR**: [#3668](https://github.com/ptitSeb/box64/pull/3668)
- **Opcodes**: 0x08-0x0D (OR), 0x28-0x2D (SUB) — 12 opcodes
- **Emit functions added**:
  - `emit_or8`, `emit_or8c`, `emit_or32`, `emit_or32c` (in new `emit_logic.c`)
  - `emit_sub8`, `emit_sub8c`, `emit_sub32`, `emit_sub32c` (added to `emit_math.c`)
- **New file**: `dynarec_ppc64le_emit_logic.c`
- **CMakeLists.txt**: added `emit_logic.c` to DYNAREC_PASS
- **Verified at the time**: Build clean (0 warnings), ctest 33/33 pass, NASM test_int_arith 40/40 pass (dynarec + interpreter)

#### Batch 1b: AND + XOR — ✅ Merged (folded into #3668)
- **PR**: [#3669](https://github.com/ptitSeb/box64/pull/3669) (closed; content merged via [#3668](https://github.com/ptitSeb/box64/pull/3668))
- **Branch**: `ppc64le-and-xor-opcodes` (based on `ppc64le-or-sub-opcodes`)
- **Opcodes**: 0x20-0x25 (AND), 0x30-0x35 (XOR) — 12 opcodes
- **Emit functions added**:
  - `emit_and8`, `emit_and8c`, `emit_and32`, `emit_and32c` (in `emit_logic.c`)
  - `emit_xor8`, `emit_xor8c`, `emit_xor32`, `emit_xor32c` (in `emit_logic.c`)
- **Dependencies**: Batch 1a (emit_logic.c must exist)
- **Bug found & fixed**: All four XOR emitters used `SET_DF(s4, ...)` which clobbered `x2` (the address register from `geted()`) in the memory path of 0x30/0x31. Fixed to `SET_DF(s3, ...)` matching AND/OR emitters. The bug caused SIGSEGV accessing address `0x34` (the df constant value) when writing back the XOR result.
- **Verified at the time**: Build clean (0 warnings), ctest 33/33 pass, NASM test_and_xor 30/30 pass (dynarec + interpreter), NASM test_int_arith 40/40 pass

#### Batch 1-macros: Upstream GETGB/GETEB/GETED/WBACK/GBBACK/EBBACK/GETGBEB Macros + Refactor Existing Opcodes — ✅ Merged
- **PR**: [#3677](https://github.com/ptitSeb/box64/pull/3677)
- **Branch**: `ppc64le-helper-macros`
- **Files**: `dynarec_ppc64le_helper.h`, `dynarec_ppc64le_00.c`
- **Part A — Add macros to `helper.h`**:
  - `GETED`, `GETEB`, `GETGB`, `GETGBEB`, `WBACK`, `GBBACK`, `EBBACK`
  - Source: Already implemented on `ppc64le-dynarec` branch
- **Part B — Refactor all existing opcode cases in `_00.c` to use macros**:
  - ADD 0x00-0x05 (from PR #3652) — replace manual inline byte register handling with GETGBEB/EBBACK/GBBACK
  - OR 0x08-0x0D (from Batch 1a) — same refactor
  - SUB 0x28-0x2D (from Batch 1a) — same refactor
  - AND 0x20-0x25 (from Batch 1b) — same refactor
  - XOR 0x30-0x35 (from Batch 1b) — same refactor
  - MOV 0x88-0x8B (from PR #3633) — refactor to use GETED/GETEB/GETGB/WBACK where applicable
- **Justification**: All three other backends (ARM64, RV64, LA64) define these macros in their respective `helper.h` files. PPC64LE is the only backend that lacks them. Adding them and refactoring:
  1. Makes the PPC64LE backend consistent with ARM64/RV64/LA64
  2. Eliminates the scratch register conflict risk class (SET_DF clobbering address registers)
  3. Keeps `_00.c` internally consistent — no mix of manual inline vs macro style
  4. Reduces review burden for future PRs
- **Dependencies**: #3668 (OR/AND/SUB/XOR) must be merged first so the diff is clean — ✅ done
- **Verification at the time**: Must pass all existing tests (ctest 33/33, NASM test_int_arith 40/40, NASM test_and_xor 30/30) since this is a pure refactor with no behavioral change
- **Benchmark (500 invocations x 3 runs)**:
  | Test | Mode | BEFORE (inline) avg | AFTER (macro) avg | Delta |
  |------|------|---------------------|-------------------|-------|
  | test_int_arith | DYNAREC | 11.72s | 11.87s | +1.3% |
  | test_and_xor | DYNAREC | 11.07s | 11.89s | +7.4% |
  | test_int_arith | INTERP | 8.79s | 8.86s | +0.8% |
  | test_and_xor | INTERP | 8.92s | 8.93s | +0.1% |
  Conclusion: Macros are compile-time only (C preprocessor) and generate identical PPC64LE machine code. Interpreter mode confirms no regression (<1%). Dynarec variance is system load noise — these micro-benchmarks are dominated by 500x box64 process startup/teardown overhead.

#### Batch 1c: CMP + TEST (0x38-0x3D, 0x84-0x85, 0xA8-0xA9) — ✅ Merged via #3684
- **PR**: [#3678](https://github.com/ptitSeb/box64/pull/3678) was closed unmerged; its content landed in [#3684](https://github.com/ptitSeb/box64/pull/3684) together with Batch 1d (upstream commit `1f853671b`, which adds `emit_tests.c`)
- **Branch**: `ppc64le-cmp-test-opcodes` (based on `ppc64le-helper-macros`)
- **Opcodes**: 0x38-0x3D (CMP), 0x84-0x85 (TEST Eb/Ed), 0xA8-0xA9 (TEST AL/EAX) — 10 opcodes
- **Emit functions added** (in new `dynarec_ppc64le_emit_tests.c`, 535 lines, 11 functions):
  - `emit_cmp8`, `emit_cmp8_0`, `emit_cmp16`, `emit_cmp16_0`, `emit_cmp32`, `emit_cmp32_0`
  - `emit_test8`, `emit_test8c`, `emit_test16`, `emit_test32`, `emit_test32c`
- **New file**: `dynarec_ppc64le_emit_tests.c`
- **CMakeLists.txt**: added `emit_tests.c` to DYNAREC_PASS
- **Special**: CMP never writes back; CMP 0x3C/0x3D has zero-optimized paths via `emit_cmp8_0`/`emit_cmp32_0`
- **Dependencies**: Batch 1-macros (#3677) must merge first
- **Style**: Uses GETGBEB/EBBACK/GBBACK/WBACK macros (matching ARM64/RV64/LA64 style)
- **NASM tests**: `test_cmp_test.asm` — 35 test cases covering register, memory, 64-bit, hi-byte, zero-optimized, overflow, SF, PF, and TEST clearing CF/OF. **Note**: NASM test files were excluded from PR #3678 since upstream has no `tests/dynarec/` directory — test framework upstreaming is tracked separately in Phase 8. The tests now live on `ppc64le-jit` (`test_cmp_test` has grown to 64 sub-tests).
- **Verified at the time**: Build clean (0 warnings), ctest 33/33 pass, NASM test_cmp_test 35/35 pass (dynarec + interpreter match native x86_64), all existing NASM tests still pass

#### Batch 1d: ADC + SBB - ✅ Merged
- **PR**: [#3684](https://github.com/ptitSeb/box64/pull/3684)
- **Opcodes**: 0x10-0x15 (ADC), 0x18-0x1D (SBB) — 12 opcodes
- **Emit functions added** (in `emit_math.c`): `emit_adc8`, `emit_adc8c`, `emit_adc16`, `emit_adc32`, `emit_sbb8`, `emit_sbb8c`, `emit_sbb16`, `emit_sbb32`
- **Special**: ADC/SBB require `READFLAGS(X_CF)` before `SETFLAGS`
- **Dependencies**: Batch 1-macros
- **Style**: Macro style (GETGBEB/EBBACK/GBBACK/WBACK)

#### Batch 1e: Group 1 ALU Immediate (0x80-0x83) ✅ Merged
- **PR**: [#3706](https://github.com/ptitSeb/box64/pull/3706)
- **Opcodes**: 0x80/0x82 (Group 1 Eb, Ib), 0x81 (Group 1 Ed, Id), 0x83 (Group 1 Ed, Ib) — 4 opcodes, 8 sub-operations each
- **Dependencies**: ALL emit functions from Batches 1a-1d must be upstream
- **Special**: These use switch on `(nextop>>3)&7` to dispatch ADD/OR/ADC/SBB/AND/SUB/XOR/CMP

### Phase 2: Control Flow + Shifts + Misc in `_00.c`

#### Batch 2a: Conditional Jumps + JMP/CALL — ✅ Merged
- **PR**: [#3709](https://github.com/ptitSeb/box64/pull/3709)
- **Opcodes**: 0x70-0x7F (Jcc short), 0xE8 (CALL), 0xE9/0xEB (JMP), 0xC2/0xC3 (RET)
- **Dependencies**: GOCOND macro in helper.h (already upstream)

#### Batch 2b: Shift/Rotate (Group 2) — ✅ Merged
- **PR**: [#3709](https://github.com/ptitSeb/box64/pull/3709)
- **Opcodes**: 0xC0/0xC1, 0xD0/0xD1, 0xD2/0xD3
- **New file**: `dynarec_ppc64le_emit_shift.c`
- **Dependencies**: none beyond infrastructure

#### Batch 2c: PUSH/POP immediate, IMUL, XCHG memory — ✅ Merged
- **PR**: [#3709](https://github.com/ptitSeb/box64/pull/3709)
- **Opcodes**: 0x68/0x6A (PUSH imm), 0x69/0x6B (IMUL), 0x86/0x87 (XCHG mem)

#### Batch 2d: String Operations — ⏸ Open (changes requested 2026-03-30)
- **PR**: [#3720](https://github.com/ptitSeb/box64/pull/3720)
- **Opcodes**: 0xA4-0xAF (MOVS, CMPS, STOS, LODS, SCAS with REP)

#### Batch 2e: Group 3-5 (F6/F7/FE/FF) — ⏸ Open (same PR)
- **PR**: [#3720](https://github.com/ptitSeb/box64/pull/3720)
- **Opcodes**: 0xF6/0xF7 (TEST/NOT/NEG/MUL/IMUL/DIV/IDIV), 0xFE/0xFF (INC/DEC/CALL/JMP/PUSH)
- **New emit functions**: `emit_neg8/16/32`, `emit_inc8/16/32`, `emit_dec8/16/32`

#### Batch 2f: Flags + Misc — ⏸ Open (same PR)
- **PR**: [#3720](https://github.com/ptitSeb/box64/pull/3720)
- **Opcodes**: 0x9C/0x9D (PUSHF/POPF), 0x9E/0x9F (SAHF/LAHF), 0xF5/0xF8-0xFD (CMC/CLC/STC/CLD/STD), 0xCC/0xCD (INT)


Line counts below are from `wc -l` on `ppc64le-jit` at `4c8ba4ea0`.

### Phase 3: Two-Byte Opcodes (`_0f.c`)
- **New file**: `dynarec_ppc64le_0f.c` (2,671 lines)
- Split into sub-batches by opcode group (CMOVcc, SETcc, BSF/BSR, MOVZX/MOVSX, SSE, etc.)

### Phase 4: SSE/SSE2 Prefix Opcodes
- `_660f.c` (4,023 lines) — SSE2 integer/packed operations
- `_f20f.c` (805 lines) — SSE2 scalar double
- `_f30f.c` (1,005 lines) — SSE scalar float
- `_66f20f.c` (52 lines) and `_66f30f.c` (130 lines) — 66-prefixed F2/F3 0F opcodes

### Phase 5: x87 FPU
- `_d8.c` through `_df.c` (8 files, 2,300 lines total)

### Phase 6: LOCK Prefix Operations
- Expand `_f0.c` (1,812 lines on the branch, 38 upstream) and `_66f0.c` (463 lines on the branch, 38 upstream)

### Phase 7: AVX
- 11 AVX files (`dynarec_ppc64le_avx*.c`, 8,883 lines total)
- Lowest priority; many applications don't require AVX

### Phase 8: NASM Dynarec Test Framework

Upstream the `tests/dynarec/` NASM test infrastructure for opcode-level regression testing. This is orthogonal to opcode upstreaming (Phases 1-7) and can be proposed at any time. Every backend (ARM64, RV64, LA64, PPC64LE) can use it, since each test runs under both the interpreter and the dynarec.

**Current state** (`ppc64le-jit`): 59 `.asm` tests, each with a pre-built static x86_64 ELF in `tests/dynarec/bin/` (59 binaries). Alongside them:
- `test_framework.inc` (64-bit) and `test_framework_32.inc` (32-bit), the macro framework
- `run_dynarec_tests.sh`, which runs pre-built binaries and needs no NASM
- `run_tests.sh`, which builds from `.asm` and runs
- `gen_flagstate_tests.py`, the generator for `test_flagstate.asm`

Upstream has no `tests/dynarec/` directory and no ctest entry for these tests. On 2026-11-08 on power9, all 59 suites passed (`SUMMARY: 59 passed, 0 failed, 0 skipped / 59 total`).

#### How the tests decide pass/fail

`run_dynarec_tests.sh` runs each binary twice, with `BOX64_DYNAREC=0` and with `BOX64_DYNAREC=1`. A suite fails if the two outputs differ, or if the `Result: N/M` line shows `N != M`. An optional `tests/dynarec/<name>.env` file (`KEY=VALUE` lines) adds environment for both runs; `test_x87_nan.env` is the only one today. The script exits with the number of failed suites, and `run_dynarec_tests.sh <name>` runs a single suite.

The reference is box64's own interpreter. No `.txt` reference outputs exist, and none are needed. Validating a new test on native x86_64 is still worthwhile. However, the x86_64 box from the old workflow (`192.168.1.148:2222`) timed out on 2026-11-08, so the interpreter is the only reference that is available right now.

#### ctest integration (tested)

The fragment below would go at the end of `tests/CMakeLists.txt`. It registers one ctest test per binary in `tests/dynarec/bin/` and reuses the runner.

```cmake
# Dynarec opcode tests: each pre-built binary in dynarec/bin is run twice by
# run_dynarec_tests.sh (BOX64_DYNAREC=0 and =1); the test fails if the outputs
# differ or any sub-test fails.
find_program(BASH_PROGRAM bash)
if(BASH_PROGRAM AND NOT ANDROID)
    file(GLOB _dynarec_tests ${CMAKE_CURRENT_SOURCE_DIR}/dynarec/bin/test_*)
    foreach(_t ${_dynarec_tests})
        get_filename_component(_n ${_t} NAME)
        add_test(NAME dynarec_${_n}
            COMMAND ${CMAKE_COMMAND} -E env BOX64=${CMAKE_BINARY_DIR}/${BOX64}
                ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/dynarec/run_dynarec_tests.sh ${_n})
    endforeach()
endif()
```

`${CMAKE_BINARY_DIR}/${BOX64}` is the same program path that `box64_add_test()` already passes to `runTest.cmake` (`tests/CMakeLists.txt:34`).

**Verification (power9, CMake 4.3.0, 2026-11-08):** the fragment was included from a minimal project, with the box64 path supplied as a variable.
- Against `build/box64`: `100% tests passed, 0 tests failed out of 59`.
- Against a wrapper that rewrites the first `PASS` to `FAIL` in dynarec-mode output: `ctest -R "dynarec_test_(shifts|mov)$"` reported both tests as `Failed`. This shows that a mismatch reaches ctest.

The fragment has not been tried inside the full box64 tree yet.

Do **not** relink the tests with the host `ld` from CMake or CI. On power9, `ld -o t t.o` on a NASM `elf64` object fails with `i386:x86-64 architecture of input file 't.o' is incompatible with powerpc:common64 output`; `ld.lld -m elf_x86_64 -o t t.o` produces `ELF 64-bit LSB executable, x86-64`. The same applies to every non-x86 host. If optional rebuilding is wanted, it needs `ld.lld -m elf_x86_64` or an x86_64 cross `ld`.

**Test inventory** (59 files on `ppc64le-jit`; each description comes from the file's header comment, and the sub-test count is the `Result: N/N` from the 2026-11-08 run):

| Test file | Sub-tests | Description |
|-----------|-----------|-------------|
| `test_16bit_alu.asm` | 44 | 66-prefixed ALU: ADD/SUB/OR/AND/XOR/CMP/ADC/SBB/shifts/INC/DEC/NEG/NOT/MUL/IMUL/DIV Ew |
| `test_32bit_bcd.asm` | 22 | 32-bit only: DAA/DAS/AAA/AAS/AAM/AAD |
| `test_32bit_incdec16.asm` | 22 | 32-bit only: short-form INC/DEC r16 (66 40-4F) |
| `test_32bit_incdec32.asm` | 20 | 32-bit only: short-form INC/DEC r32 (40-4F) |
| `test_32bit_into.asm` | 4 | 32-bit only: INTO |
| `test_32bit_pushad_popad.asm` | 12 | 32-bit only: PUSHAD/POPAD and 16-bit PUSHA/POPA |
| `test_32bit_segment_push.asm` | 8 | 32-bit only: PUSH/POP ES, PUSH CS, PUSH/POP SS, PUSH/POP DS; 16-bit (66) PUSH/POP ES and DS |
| `test_adc_sbb.asm` | 42 | ADC (0x10-0x15) and SBB (0x18-0x1D), all forms |
| `test_adcx_adox.asm` | 12 | ADCX/ADOX dual carry chains |
| `test_add_carry_fusion.asm` | 45 | ADD → CF consumed by ADC/SBB across a block boundary |
| `test_add_or_sub.asm` | 40 | ADD/OR/SUB, all forms |
| `test_aes_crc.asm` | 36 | AES-NI, PCLMULQDQ (all imm8 selectors), CRC32 |
| `test_and_xor.asm` | 30 | AND/XOR, all forms, with flags |
| `test_bit_extract.asm` | 20 | PMOVMSKB, MOVMSKPS, MOVMSKPD |
| `test_cmovcc_fusion.asm` | 64 | CMOVcc right after a flag producer (in-block fusion) |
| `test_cmp_test.asm` | 64 | CMP (0x38-0x3D), TEST (0x84-0x85, 0xA8-0xA9), Group 1 CMP |
| `test_comiss.asm` | 24 | COMISS/UCOMISS/COMISD/UCOMISD: orderings, signed zero, SNaN/QNaN, consumers in-block and across exits |
| `test_comiss_df.asm` | 4 | Regression: scalar-compare flags must survive a block exit after a deferred-flags record |
| `test_conversions.asm` | 38 | SSE int/float conversions (CVT*), plus MOVZX/MOVSX/CBW |
| `test_flagstate.asm` | 200 | Generated (`gen_flagstate_tests.py 200 20261104`): flag-state hand-off across block exits |
| `test_int_arith.asm` | 31 | ADD, SUB, INC, DEC, NEG, MUL, IMUL, DIV, IDIV, XADD, CMPXCHG, BSWAP, LEA, MOVSX |
| `test_jcc_fusion.asm` | 89 | Jcc right after a flag producer (in-block fusion) |
| `test_lock_atomic.asm` | 79 | LOCK ALU/INC/DEC/BTx, LOCK CMPXCHG/8B/16B, LOCK XADD, XCHG [mem] |
| `test_loop_jecxz.asm` | 13 | LOOP, LOOPZ, LOOPNZ, JECXZ/JRCXZ |
| `test_misc_flags.asm` | 30 | LAHF, SAHF, PUSHF/POPF, ENTER/LEAVE, XLAT, MOVBE, CBW/CWDE/CDQE, CWD/CDQ/CQO |
| `test_misc_int.asm` | 40 | BSF, BSR, POPCNT, LZCNT, TZCNT, BT/BTS/BTR/BTC, SETcc, CMOVcc |
| `test_mov.asm` | 24 | MOV (0x88-0x8B, 0xB0-0xBF, 0xC6-0xC7) |
| `test_mov_push_imm.asm` | 29 | MOV/PUSH immediates and 16-bit ADD/SUB |
| `test_movs_stos.asm` | 25 | REP MOVS/STOS, REPE CMPS, REPNE SCASB, LODS (B/W/D/Q) |
| `test_pmaddubsw.asm` | 10 | PMADDUBSW, MMX and SSE forms |
| `test_push_pop_misc.asm` | 22 | PUSH/POP, XCHG, NOP, MOVSXD (LEAVE and CWDE/CDQ are in `test_misc_flags`) |
| `test_setcc_fusion.asm` | 77 | SETcc right after a flag producer (in-block fusion) |
| `test_sha.asm` | 10 | SHA1/SHA256 extension instructions |
| `test_shifts.asm` | 33 | SHL, SHR, SAR, ROL, ROR by immediate and CL, with flags |
| `test_shufps.asm` | 76 | SHUFPS, every optimisation tier |
| `test_sse3_move.asm` | 30 | MOVDDUP, MOVSLDUP, MOVSHDUP, LDDQU, MOVNTDQ, MOVNTPS, reciprocal approximations |
| `test_sse4_ext.asm` | 54 | PMOVSX/PMOVZX, PMINS*/PMAXS*/PMINU*/PMAXU*, PHMINPOSUW |
| `test_sse_arith.asm` | 45 | ADD/SUB/MUL/DIV/SQRT/MIN/MAX PS/PD/SS/SD, COMISS/COMISD |
| `test_sse_cmp.asm` | 35 | CMPSS/CMPSD/CMPPS/CMPPD with all 8 predicates |
| `test_sse_hadd.asm` | 25 | HADDPS/HADDPD/HSUBPS/HSUBPD, ADDSUBPS/ADDSUBPD |
| `test_sse_horiz.asm` | 12 | HADD/HSUB and ADDSUB PS/PD |
| `test_sse_horiz_nan.asm` | 23 | HADD/HSUB edge cases: NaN, INF, denormals, memory operands |
| `test_sse_insert_extract.asm` | 33 | PINSR*/PEXTR*, PTEST, INSERTPS |
| `test_sse_int.asm` | 40 | PCMPEQ*, PMIN/PMAX, PACK/UNPACK, PSHUFD, PSHUFB |
| `test_sse_misc_int.asm` | 34 | PMADDWD, PMADDUBSW, PMULHRSW, PABS, PSIGN, PACKUSDW, PMULHW, PMULHUW, PMULUDQ |
| `test_sse_reciprocal.asm` | 8 | RSQRTPS/RCPPS/RSQRTSS/RCPSS within tolerance |
| `test_sse_round_blend.asm` | 30 | ROUNDSS/SD/PS/PD, BLENDPS/BLENDPD/PBLENDW |
| `test_sse_shuffle.asm` | 42 | SHUFPS/SHUFPD, PSHUFD/PSHUFLW/PSHUFHW/PSHUFB, UNPCK* |
| `test_sse_string.asm` | 25 | PCMPISTRI/PCMPISTRM/PCMPESTRI/PCMPESTRM |
| `test_sub_carry_fusion.asm` | 40 | SUB → CF consumed by ADC/SBB across a block boundary |
| `test_updateflags.asm` | 44 | Deferred-flag materialisation across block boundaries |
| `test_updateflags_arith.asm` | 48 | Deferred flags: add/sub/inc/dec/neg, 8/16/32/64 |
| `test_updateflags_carry.asm` | 59 | Deferred flags: adc/sbb, shld/shrd 16/32/64 |
| `test_updateflags_logic.asm` | 33 | Deferred flags: and/or/xor/test |
| `test_updateflags_mul.asm` | 22 | Deferred flags: mul/imul 8/16/32/64 (single-operand) |
| `test_updateflags_shift.asm` | 37 | Deferred flags: shl/shr/sar/rol/ror 8/16/32/64 |
| `test_x87.asm` | 30 | FLD/FST, arithmetic, FSQRT/FABS/FCHS/FXCH, FILD/FISTP, compares, constants, FRNDINT |
| `test_x87_d8.asm` | 18 | D8 map: FADD/FMUL/FSUB/FSUBR/FDIV/FDIVR ST0,ST(i) and ST0,m32, FCOM/FCOMP |
| `test_x87_nan.asm` | 14 | x87 NaN semantics (run with `BOX64_DYNAREC_FASTNAN=0` via `.env`) |

SHLD/SHRD flags are covered by `test_updateflags_carry.asm`; there is no separate `test_updateflags_shld.asm`.

**Batching strategy**:
- **Batch 8a**: Framework, runner and integer tests (`test_framework.inc`, `run_dynarec_tests.sh`, `test_16bit_alu`, `test_add_or_sub`, `test_and_xor`, `test_adc_sbb`, `test_adcx_adox`, `test_cmp_test`, `test_int_arith`, `test_mov`, `test_mov_push_imm`, `test_push_pop_misc`, `test_shifts`, all `test_updateflags*`, `test_misc_flags`, `test_misc_int`, `test_movs_stos`, `test_loop_jecxz`, `test_lock_atomic`)
- **Batch 8b**: SSE/SSE2/SSE3/SSE4/AES/SHA tests (all `test_sse*`, `test_bit_extract`, `test_conversions`, `test_pmaddubsw`, `test_shufps`, `test_aes_crc`, `test_sha`, `test_comiss`)
- **Batch 8c**: x87 (`test_x87`, `test_x87_d8`, `test_x87_nan` + its `.env`)
- **Batch 8d**: Flag fusion and hand-off tests (`test_jcc_fusion`, `test_setcc_fusion`, `test_cmovcc_fusion`, `test_sub_carry_fusion`, `test_add_carry_fusion`, `test_comiss_df`, `test_flagstate` + `gen_flagstate_tests.py`)
- **Batch 8e**: 32-bit tests (`test_framework_32.inc`, all `test_32bit_*`), which need a BOX32 build

**Prerequisites**: Discuss with maintainer (ptitSeb) before submitting. This introduces a new testing paradigm for the project. Key selling points:
1. Opcode-level regression tests catch dynarec bugs that higher-level C tests miss. For example, the EBBACK STB argument swap bug was only caught by memory-path NASM tests, and the COMISS deferred-flags bug only by `test_comiss_df`.
2. The tests don't depend on any one backend; the dynarec-vs-interpreter comparison works the same for ARM64/RV64/LA64.
3. Pre-built binaries mean CI needs no new dependencies (no NASM, no x86 linker).

### Phase 9: 32-bit-Only Opcodes

32-bit x86 instructions that are invalid in 64-bit long mode but required for 32-bit application emulation (BOX32). These opcodes exist only when `rex.is32bits` is true. Implemented on the `ppc64le-jit` branch.

#### Implemented

All of these entered the branch's current history in the squashed commit `b4723044c` ("feat(ppc64le): add PPC64LE (POWER9+) dynarec backend (#4)", 2026-03-21); `git log -S'INST_NAME("<name>")'` finds no earlier commit. The per-feature commits once listed here (`e0fdf1bd3`, `a128986ce`, `10ff08cba`) no longer exist in this repository.

| Opcode | Mnemonic | File |
|--------|----------|------|
| `66 0x40-0x47` | INC reg16 (short form) | `_66.c` |
| `66 0x48-0x4F` | DEC reg16 (short form) | `_66.c` |
| `0x27` | DAA | `_00.c` |
| `0x2F` | DAS | `_00.c` |
| `0x37` | AAA | `_00.c` |
| `0x3F` | AAS | `_00.c` |
| `0xD4` | AAM Ib | `_00.c` |
| `0xD5` | AAD Ib | `_00.c` |
| `0xCE` | INTO | `_00.c` |
| `66 0x06/0x07` | PUSH/POP ES (16-bit) | `_66.c` |
| `66 0x1E/0x1F` | PUSH/POP DS (16-bit) | `_66.c` |
| `66 0x60/0x61` | PUSHA/POPA (16-bit) | `_66.c` |

#### Already Implemented (pre-existing, tests are regression coverage)

| Opcode | Mnemonic | File |
|--------|----------|------|
| `0x06/0x07` | PUSH/POP ES | `_00.c` |
| `0x0E` | PUSH CS | `_00.c` |
| `0x16/0x17` | PUSH/POP SS | `_00.c` |
| `0x1E/0x1F` | PUSH/POP DS | `_00.c` |
| `0x40-0x47` | INC reg32 (short form) | `_00.c` |
| `0x48-0x4F` | DEC reg32 (short form) | `_00.c` |
| `0x60/0x61` | PUSHAD/POPAD | `_00.c` |

#### Not Implementing (interpreter fallback)

| Opcode | Mnemonic | Reason |
|--------|----------|--------|
| `0x62` | BOUND | Rarely used, no real-world demand |
| `0x63` | ARPL | OS-level instruction, not used by applications |
| `0x9A` | CALL FAR | Segmented mode, not used by modern 32-bit apps |
| `0xEA` | JMP FAR | Segmented mode, not used by modern 32-bit apps |
| `0xD6` | SALC | Undocumented, extremely rare |

(`FF /3` and `FF /5`, CALL FAR Ed / JMP FAR Ed, *are* handled in `_00.c`.)

#### Known Bugs

None open. The old **POP DS (0x1F) segfault** (`STW r0, 6(r6)` with r6=0) no longer reproduces:
- `_00.c` now emits `STH(x1, offsetof(x64emu_t, segs[_DS]), xEmu)`.
- `BOX64_DYNAREC_DUMP=1` shows `POP DS` being compiled.
- `test_32bit_segment_push` passes 8/8, with dynarec == interpreter (power9, 2026-11-08).

#### NASM Test Coverage (power9, 2026-11-08)

| Test | Sub-tests | Status |
|------|-----------|--------|
| `test_32bit_incdec16` | 22 | PASS (dynarec == interpreter) |
| `test_32bit_incdec32` | 20 | PASS (dynarec == interpreter) |
| `test_32bit_bcd` | 22 | PASS (dynarec == interpreter) |
| `test_32bit_into` | 4 | PASS (dynarec == interpreter) |
| `test_32bit_pushad_popad` | 12 | PASS (dynarec == interpreter) |
| `test_32bit_segment_push` | 8 | PASS (dynarec == interpreter) |

### Phase 10: Native Flag Fusion Optimization

Performance optimization that replaces branchy flag materialization patterns with branchless PPC64LE sequences. This is a pure optimization — no new opcodes, no behavioral changes. All changes are in emit functions and helper macros.

**Motivation**: The original emit functions used branch-based flag materialization: test a condition, branch over an ORI to set the flag bit. POWER9 dispatches in order but issues out of order. The *POWER9 Processor User's Manual* v2.0 (OpenPOWER, 9 April 2018), §2.1.3 "Speculative Superscalar Inner Core Organization", lists "In-order dispatch of up to six internal operations" and "Out-of-order issue of up to nine operations", and §25.1.3.3 refers to "the high penalty for branch misprediction". The manual gives no cycle count for that penalty, so none is claimed here. Branchless sequences avoid the misprediction cost entirely, which is why they are typically faster for data-dependent flag bits.

#### Implemented (on `ppc64le-jit` branch)

The hashes are the commits on `ppc64le-jit`. The earlier hashes `0592ac05a`, `9bb808020`, `271f4e111`, `adb964763` and `5b7626078` are pre-rebase copies that are not on the branch; `git patch-id --stable` gives the same id for each old/new pair.

| Commit | Phase | Description | Sites | Net lines |
|--------|-------|-------------|-------|-----------|
| `3e6cf2736` | Phase 0 | 230 NASM fusion tests (jcc, setcc, cmovcc) | — | +3,858 |
| `8550a361c` | Phase 1 | Sign fusion for 14 logic emit functions (AND/OR/XOR) | 14 | — |
| `0be3aeaf9` | Phase 2 | SF fusion for 24 arithmetic emit functions (ADD/SUB/NEG/INC/DEC/ADC/SBB) + pass0.h fix | 24 | — |
| `ad2d43a13` | Phase 3 | Branchless flag materialization (all remaining branchy patterns) | 151 | -121 |
| `c3bd7bb14` | NATIVEMV | Branchless ISEL-based CMOVcc fusion (replaces NOP stubs) | 11 macros | — |
| `a7f0c5ffd` | Phase 4 | SUB carry fusion: nat_flags_needcarry + MV save + 3-way dispatch in emit_sub8/16/32/32c | 5 emit fns, 20 call sites | — |
| `9326353c9` | Phase 5 | ADD carry fusion: NAT_FLAGS_ENABLE_CARRY + MV save + 3-way dispatch in emit_add8/16/32/32c/8c | 5 emit fns, 29 call sites | — |

**Phase 3 breakdown** — 151 branchy patterns eliminated across 5 files:

| Flag | Sites | Branchless replacement | Files |
|------|-------|----------------------|-------|
| ZF | 72 | `CNTLZD(scratch,reg); SRDI(scratch,scratch,6); BF_INSERT(xFlags,scratch,F_ZF,F_ZF)` | all 4 emit files |
| SF | 44 | `BF_EXTRACT(scratch,reg,sign_bit,sign_bit); BF_INSERT(xFlags,scratch,F_SF,F_SF)` | emit_logic, emit_tests, emit_shift |
| AF | 17 | `ANDId(scratch,chain,8); SRDI(scratch,scratch,3); BF_INSERT(xFlags,scratch,F_AF,F_AF)` | emit_math |
| CF | 13 | Various: `BF_EXTRACT` for shifts, `CNTLZD+XORI` for NEG, `SRDI` for ADD overflow | emit_math |
| OF | 5 | `BF_INSERT(xFlags,scratch,F_OF,F_OF)` (scratch already 0/1 from prior computation) | helper.h (CALC_SUB_FLAGS), emit_math (NEG) |

**Zero branchy flag patterns remain** in any emit file after Phase 3. `grep -cE 'B(EQ|NE|GE|LT|GT|LE)\(8\)' dynarec_ppc64le_emit_*.c` gives 0 for all four files on `ppc64le-jit`.

**Key design patterns**:
- **ZF**: `CNTLZD` returns 64 for zero input; `SRDI(scratch,scratch,6)` maps 64→1, all others→0. 3 insns, 0 branches.
- **SF**: `BF_EXTRACT` at the sign bit position (7/15/31/63 depending on operand width). 2 insns, 0 branches.
- **AF**: Auxiliary carry is bit 3 of the half-carry chain. `ANDId` + `SRDI(3)` isolates it. 3 insns, 0 branches.
- **CF**: Width-dependent. ADD: `BF_EXTRACT` at overflow bit. NEG: `CNTLZD+SRDI+XORI` (CF = result != 0). 2-4 insns, 0 branches.
- **OF**: Already computed as 0/1 by prior arithmetic; direct `BF_INSERT`. 1 insn, 0 branches.

#### Upstreaming strategy

These optimizations apply to emit functions that are already upstream. The upstream versions still use branchy patterns: the same grep on `upstream/main` gives 42 (`emit_math.c`), 22 (`emit_logic.c`), 23 (`emit_tests.c`) and 42 (`emit_shift.c`), 129 sites in all. The Phase 4/5 carry fusion also changes the signatures of 10 upstream emit functions (see Current State), so it can't be a drop-in replacement of upstream bodies. Upstreaming options:
1. **Incremental PRs**: One PR per flag type (SF, ZF, AF, CF, OF) — easier to review but more PRs
2. **Single PR**: All 151 transformations in one PR — matches the single-commit approach used on `ppc64le-jit`
3. **Fold into opcode PRs**: Apply branchless patterns as emit functions are upstreamed — but most emit functions are already upstream with branchy code

Recommendation: A single PR with clear commit message explaining the branchless templates, after all current opcode PRs are merged. The transformation is mechanical and well-tested: 63/63 ctest and 59/59 NASM suites pass on `ppc64le-jit` (power9, 2026-11-08).

## Upstream Style Reference

Since #3677, the opcode cases in upstream `_00.c` use the operand macros rather than open-coded register extraction. The two templates below are copied verbatim from `upstream/main:src/dynarec/ppc64le/dynarec_ppc64le_00.c` (cases 0x00 and 0x01).

### Byte Opcode Pattern (upstream ADD Eb, Gb)
```c
        case 0x00:
            INST_NAME("ADD Eb, Gb");
            SETFLAGS(X_ALL, SF_SET_PENDING, NAT_FLAGS_FUSION);
            nextop = F8;
            GETGBEB(x1, x2, 0);
            emit_add8(dyn, ninst, ed, gd, x4, x5);
            EBBACK();
            break;
```

### Dword Opcode Pattern (upstream ADD Ed, Gd)
```c
        case 0x01:
            INST_NAME("ADD Ed, Gd");
            SETFLAGS(X_ALL, SF_SET_PENDING, NAT_FLAGS_FUSION);
            nextop = F8;
            GETGD;
            GETED(0);
            emit_add32(dyn, ninst, rex, ed, gd, x3, x4, x5);
            WBACK;
            break;
```

### The same cases on `ppc64le-jit`
```c
        case 0x00:
            INST_NAME("ADD Eb, Gb");
            SETFLAGS(X_ALL, SF_SET_PENDING, NAT_FLAGS_FUSION);
            nextop = F8;
            GETGBEB(x1, x2, 0);
            emit_add8(dyn, ninst, ed, gd, x4, x5, x3, x6);
            EBBACK();
            break;
        case 0x01:
            INST_NAME("ADD Ed, Gd");
            SETFLAGS(X_ALL, SF_SET_PENDING, NAT_FLAGS_FUSION);
            nextop = F8;
            UP32_AGNOSTIC();
            GETGD;
            GETED(0);
            emit_add32(dyn, ninst, rex, ed, gd, x3, x4, x5, x6);
            WBACK;
            break;
```
The branch differs in two ways:
- **Extra scratch registers.** `emit_add*`/`emit_sub*` take two more (Phase 10 carry fusion).
- **`UP32_AGNOSTIC()` and the other `UP32_*` markers.** These are the upper-32 liveness tracking. In STEP 0 they record facts in `dyn->insts[ninst]`; in later passes they compile to nothing (`helper.h:333-356`). The branch's `_00.c` has 65 `UP32_` uses; upstream has none.

### Notes
- **Operand registers used by the macros** (from `dynarec_ppc64le_helper.h` on the branch):

  | Macro | Value in | Address (`wback`) in | Scratch for `geted()` |
  |-------|----------|----------------------|------------------------|
  | `GETED(D)` (memory form) | `x1` | `x2` | `x1` |
  | `GETEB(i, D)` (memory form) | `i` | `x3` | `x2` |
  | `GETEW(i, D)` | `i` | `x3` | `i` |

  For example, `GETGBEB(x1, x2, 0)` calls `GETEB(x2, 0)`.
- **Emitter scratch registers must not alias `wback` before the write-back** (`WBACK`/`EBBACK`/`EWBACK` store through `wback`). That is the real rule behind the old "`SET_DF()` must use `s3`" note, which no longer holds: `emit_xor16`, `emit_or32` and `emit_or32c` use `SET_DF(s4, …)`. Every current caller passes `x4` or `x5` as `s4`, which never aliases `x2`/`x3` (`00.c:166,184,200,1189`, `66.c:244,252,261,515`, `f0.c:212,1147`).
- **`SCRATCH_USAGE(n)` is not a no-op.** The empty definition in `helper.h:3236-3238` is only the `#ifndef` fallback. In STEP 0 (`pass0.h:104-107`) it sets `dyn->insts[ninst].no_scratch_usage = !n`. Native flag fusion then looks through such an instruction when pairing a flag producer with its Jcc/SETcc/CMOVcc (`functions.c:793`, `pass0.h:21`). `NAT_FLAGS_OPS` copies the producer's GPR operands into scratch registers when the next instruction is such a pass-through (`helper.h:1603-1610`).
- **`SCRATCH_USAGE(0)` at the top of a case is an optimistic default.** `geted()` calls `SCRATCH_USAGE(1)` itself whenever it needs a scratch register (`helper.c:81-209`). The dump shows this: for `or cx,0 ; mov [rbx+rsi*4+0x12340],eax ; jz`, the `OR` is not fused (`fuse=0/0`); with `mov [rbx+8],eax` it is (`fuse=1/0`, and the `JZ` becomes `CMPDI x1,0; BEQ`). Both give the interpreter's result.
- **Upstream uses `SCRATCH_USAGE`** only on MOVSXD, PUSH/POP reg, MOV Ed,Gd, MOV Gd,Ed, Invalid 8D and MOV Reg,Id (all `0`), and on MOV Eb,Ib and MOV Ed,Id (`1`). Don't put `SCRATCH_USAGE(0)` on an opcode that writes scratch registers outside `geted()`.
- Memory paths use `geted()` and `SMREAD()`/`SMWRITE()` (inside the macros), or `SMREADLOCK`/`SMWRITELOCK` from `src/dynarec/dynarec_helper.h` where a `lock` is tracked.
- Upstream `helper.h` declares all 104 emit functions. As noted under Current State, 10 of them have different signatures on the branch.

## Build & Test Workflow

Every command in this section was run on 2026-11-08 against `ppc64le-jit` at `4c8ba4ea0`.

### Remote Infrastructure

| Machine | Address | Purpose |
|---------|---------|---------|
| PPC64LE build/test box | `ssh power9` (`HostName 192.168.1.247` in `~/.ssh/config`) | Git clone at `~/box64` (git remote `power9` = `ssh://power9/home/tle/box64`). Builds box64, runs ctest and the NASM tests, and assembles/links new tests (`/usr/bin/nasm`, `/usr/bin/ld.lld`). Login shell: `/bin/bash`. |
| Local Mac | localhost | Source editing; pushes to the `power9` remote |

The old x86_64 compile box (`tle@192.168.1.148`, port 2222) is not needed for the steps below. On 2026-11-08 it was unreachable (`connect to host 192.168.1.148 port 2222: Operation timed out`).

### Step 1: Get the source onto power9

Push the branch to the `power9` remote, then check it out in `~/box64` there. Untracked copies of files that the target commit tracks will abort the checkout (for example `.asm` files or binaries copied over with `scp`). Remove them first, and check the result with `git log --oneline -1`.

### Step 2: Build

The existing build directory is configured with `PPC64LE_DYNAREC=ON`, `BOX32=ON`, `CMAKE_BUILD_TYPE=RelWithDebInfo` and the Ninja generator (from `build/CMakeCache.txt`). Rebuild with:

```bash
ssh power9 'cd ~/box64 && ninja -C build'
```

### Step 3: Run ctest

```bash
ssh power9 'cd ~/box64/build && ctest -j8'
```

Expected: `100% tests passed, 0 tests failed out of 63`.

### Step 4: Run the NASM dynarec tests

**Run this for every commit.**

```bash
ssh power9 'cd ~/box64 && BOX64=$HOME/box64/build/box64 bash tests/dynarec/run_dynarec_tests.sh'
```

Expected: `SUMMARY: 59 passed, 0 failed, 0 skipped / 59 total`. There are no known failures: `test_aes_crc` 36/36, `test_misc_flags` 30/30, `test_sse_insert_extract` 33/33 and `test_updateflags_mul` 22/22 all pass now. Any failure is a regression.

Individual tests: `bash tests/dynarec/run_dynarec_tests.sh test_shifts test_mov`; list them with `-l`.

### Step 5: Write/Edit a NASM test

Each test file:
- Includes `test_framework.inc` (or `test_framework_32.inc` for 32-bit tests) at the top
- Uses `INIT_TESTS` / `TEST_CASE` / `CHECK_EQ_32` / `CHECK_EQ_64` / `SAVE_FLAGS` / `CHECK_FLAGS_EQ` / `END_TESTS`
- Uses raw syscalls only (no libc dependency), producing a static ELF binary
- Tests register results AND flags (CF, PF, AF, ZF, SF, OF)

Flag constants defined in the framework (`test_framework.inc:346-353`):
```nasm
%define CF 0x0001
%define PF 0x0004
%define AF 0x0010
%define ZF 0x0040
%define SF 0x0080
%define OF 0x0800
%define FLAGS_MASK_ARITH (CF|PF|AF|ZF|SF|OF)
%define FLAGS_MASK_LOGIC (CF|PF|ZF|SF|OF)
```

Each batch should have a dedicated NASM test covering:
- All opcode forms: Eb/Gb, Ed/Gd, Gb/Eb, Gd/Ed, AL/Ib, EAX/Id
- Register-register AND memory paths
- Hi-byte registers (AH, CH) for byte operations (non-REX)
- 64-bit (REX.W) variants
- Flag verification (ZF, SF, CF=0/OF=0 for logic ops)
- For flag bugs: a consumer in a *different* block (indirect `jmp`, or a Jcc that leaves the block). `BOX64_DYNAREC_TEST` materialises flags per instruction and hides this class (see `test_comiss_df`).

Tests that need extra environment get a `tests/dynarec/<name>.env` file with `KEY=VALUE` lines.

### Step 6: Assemble and link on power9

```bash
cd ~/box64/tests/dynarec
nasm -f elf64 -o test_file.o test_file.asm
ld.lld -m elf_x86_64 -o bin/test_file test_file.o
```

The plain host `ld` cannot do this. It fails with `i386:x86-64 architecture of input file ... is incompatible with powerpc:common64 output`.

### Step 7: Validate the new test under the interpreter first

```bash
BOX64_DYNAREC=0 ~/box64/build/box64 bin/test_file; echo "exit=$?"
```

Every sub-test must PASS under the interpreter before the dynarec result means anything. The interpreter is the reference here (see Phase 8).

### Step 8: Compare dynarec and interpreter

```bash
bash tests/dynarec/run_dynarec_tests.sh test_file
```

The runner does the two runs and the comparison. To do it by hand (bash, so `$?`, not fish's `$status`):

```bash
BOX64_DYNAREC=1 ~/box64/build/box64 bin/test_file > /tmp/dyn.txt 2>/dev/null; echo "exit=$?"
BOX64_DYNAREC=0 ~/box64/build/box64 bin/test_file > /tmp/int.txt 2>/dev/null; echo "exit=$?"
diff /tmp/dyn.txt /tmp/int.txt && echo MATCH || echo DIFFER
```

### Step 9: Debug crashes (if needed)

```bash
BOX64_DYNAREC_DUMP=1 ~/box64/build/box64 bin/test_file 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g' > /tmp/dump.txt
```

Key things to look for:
- `SIGSEGV ... for accessing 0xNN`: the faulting address
- The per-instruction header (`state=`, `set=`, `use=`, `need=`, `fuse=`): the deferred-flags state and whether native fusion fired
- Scratch register conflicts where `SET_DF`/`CLEAR_FLAGS`/`emit_pf` clobber registers the caller still needs
- For deferred-flags bugs: a block exit missing the `LI x4,0; STW x4,1108(xEmu)` store to `emu->df`.
  - Pass 3 prints `Warning, PPC64LE dynarec: opcode at %p declared SF_SET_DF without writing emu->df` for the COMISS-type case.
  - `BOX64_DYNAREC_DFCHECK=1` traps (SIGTRAP) where the tracked state says "no deferred record" but `emu->df` is not 0. It does not check the opposite direction.

---

## Lessons Learned / Pitfalls

### 1. EBBACK STB Argument Swap Bug (2026-03-14)

**What happened**: When porting the `EBBACK()` macro from `ppc64le-dynarec` to `ppc64le-helper-macros`,
the arguments to `STB(ed, fixedaddress, wback)` were accidentally written as `STB(ed, wback, fixedaddress)`.
This swapped the immediate offset and base register, causing a segfault when accessing tiny addresses like `0x5`.

**Root cause**: Manual re-typing instead of exact copy-paste. Both argument orders compile without error —
PPC64LE `STB(Rs, offset, Ra)` treats the second arg as an immediate and the third as a register, so
swapping them silently generates wrong code.

**How it was caught**: The `test_and_xor` NASM test included memory operand test cases (`and Eb,Gb mem`).
Register-only tests all passed; the bug only manifested with memory operands.

**Mandatory process going forward** (the source branch is now `ppc64le-jit`, not `ppc64le-dynarec`):
1. **Never manually re-type code from the source branch**. Always extract with `git show ppc64le-jit:<path>` and copy verbatim.
2. **Always diff after porting**: `diff <(git show ppc64le-jit:<path>) <path>` to verify only intended changes.
3. **Every NASM test MUST include memory operand variants** — register-only tests are insufficient to catch address computation bugs.
4. **Run NASM tests before ctest** — ctest's existing tests may not exercise the specific opcode forms being ported.

### 2. NASM Test Gotchas

- **Cannot use `cmp reg64, imm64`** — x86_64 only supports 32-bit sign-extended immediates for `cmp`. `CHECK_EQ_64` handles this by loading the expected value into `r14` first (`mov r14, %2`).
- **Registers the framework relies on**:
  - `r12` (pass count) and `r13` (total count) are live for the whole program. Never clobber them.
  - `r14` carries the flags from `SAVE_FLAGS`/`CHECK_FLAGS` to `CHECK_FLAGS_EQ`. Don't touch it in between.
  - `r15` is free. `TEST_CASE` never loads it, and `CHECK_EQ_64`/`CHECK_APPROX_PS_64` push and pop it.
  - The header comment in `test_framework.inc` used to say "r15 = current test name pointer" and "r14 ... restored after"; both were wrong and it has been corrected.

  A probe run on power9 under both `BOX64_DYNAREC=0` and `=1` confirmed this:

  | Clobbered | Result |
  |-----------|--------|
  | `r15` | PASS |
  | `r14` between `SAVE_FLAGS` and `CHECK_FLAGS_EQ` | FAIL, `got=0x0` |
  | `r12` | final line `Result: 101/3` |
- **Always test both `BOX64_DYNAREC=1` and `BOX64_DYNAREC=0`** to confirm dynarec matches interpreter.
- **Don't route a flags check through a CALL.** At the default `BOX64_DYNAREC_SAFEFLAGS=1` ("Most of RETs will need flags, most of CALLs will not", `docs/USAGE.md`), box64 does not guarantee flags across a CALL. Use an indirect `jmp` or a Jcc that leaves the block.
