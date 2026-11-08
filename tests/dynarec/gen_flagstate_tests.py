#!/usr/bin/env python3
"""Generate test_flagstate.asm: flag-state hand-off cases for the dynarec.

Each case chains
  A: a flag producer whose conditional jump leaves the block (so its flags
     are kept as a deferred record in emu->df),
  B: a second producer whose jump stays in the block (fused, no record),
  C: an instruction that writes some or all flags directly,
  E: an exit from the block (conditional jump, indirect jump, unconditional
     jump, call, ret),
  D: a consumer in the landing block (setcc, pushf, adc, cmovcc).
The expected value is computed here from the x86 flag semantics; flags left
undefined by the last instruction that touched them are never checked.

Usage: gen_flagstate_tests.py [count] [seed] > test_flagstate.asm (default 200 20261104)
Build: nasm -f elf64 -o test_flagstate.o test_flagstate.asm && ld.lld -m elf_x86_64 -o bin/test_flagstate test_flagstate.o
"""
import random
import sys

CF, PF, AF, ZF, SF, OF = 0x1, 0x4, 0x10, 0x40, 0x80, 0x800
ALL = CF | PF | AF | ZF | SF | OF


def parity(v):
    return PF if bin(v & 0xff).count('1') % 2 == 0 else 0


def arith(a, b, width, sub, keep_cf=None):
    """flags of a +/- b at the given width; returns (flags, defined)."""
    mask = (1 << width) - 1
    msb = 1 << (width - 1)
    a &= mask
    b &= mask
    res = (a - b) & mask if sub else (a + b) & mask
    f = 0
    if sub:
        if a < b:
            f |= CF
        if ((a ^ b) & (a ^ res)) & msb:
            f |= OF
    else:
        if a + b > mask:
            f |= CF
        if (~(a ^ b) & (a ^ res)) & msb:
            f |= OF
    if (a ^ b ^ res) & 0x10:
        f |= AF
    if res == 0:
        f |= ZF
    if res & msb:
        f |= SF
    f |= parity(res)
    if keep_cf is not None:
        f = (f & ~CF) | keep_cf
    return f, ALL


def logic(a, b, width, op):
    mask = (1 << width) - 1
    res = (a & b) if op == 'and' else (a ^ b)
    res &= mask
    f = 0
    if res == 0:
        f |= ZF
    if res & (1 << (width - 1)):
        f |= SF
    f |= parity(res)
    return f, ALL & ~AF   # AF undefined


class Flags:
    def __init__(self):
        self.val = 0
        self.defined = 0

    def apply(self, f, defined, undefined=0):
        self.val = (self.val & ~defined) | (f & defined)
        self.defined |= defined
        self.defined &= ~undefined


# ---- producers A: flags end up as a deferred record (their jump leaves the block)
def gen_A(rnd, out, fl, never):
    kind = rnd.choice(['test16', 'cmp32', 'add8', 'sub64', 'and16', 'xor32', 'dec32', 'inc8'])
    if kind == 'test16':
        v = rnd.choice([0, 1, 5, 0x8000, 0xffff])
        out.append(f'    mov r15d, {v}')
        out.append('    test r15w, r15w')
        f, d = logic(v, v, 16, 'and')
    elif kind == 'cmp32':
        a, b = rnd.choice([(7, 7), (3, 9), (9, 3), (0x80000000, 1), (0, 0xffffffff)])
        out.append(f'    mov r15d, {a}')
        out.append(f'    cmp r15d, {b}')
        f, d = arith(a, b, 32, True)
    elif kind == 'add8':
        a, b = rnd.choice([(0x7f, 1), (0xff, 1), (0x0f, 1), (3, 4)])
        out.append(f'    mov r15d, {a}')
        out.append(f'    add r15b, {b}')
        f, d = arith(a, b, 8, False)
    elif kind == 'sub64':
        a, b = rnd.choice([(1, 1), (0, 1), (5, 2), (0x8000000000000000, 1)])
        out.append(f'    mov r15, {a}')
        out.append(f'    sub r15, {b}')
        f, d = arith(a, b, 64, True)
    elif kind == 'and16':
        a, b = rnd.choice([(0xff00, 0x00ff), (0x8001, 0x8000), (7, 3)])
        out.append(f'    mov r15d, {a}')
        out.append(f'    and r15w, {b}')
        f, d = logic(a, b, 16, 'and')
    elif kind == 'xor32':
        a, b = rnd.choice([(5, 5), (0x80000000, 1), (3, 1)])
        out.append(f'    mov r15d, {a}')
        out.append(f'    xor r15d, {b}')
        f, d = logic(a, b, 32, 'xor')
    elif kind == 'dec32':
        a = rnd.choice([1, 0, 0x80000000, 7])
        out.append('    stc')                   # CF must be preserved by dec
        out.append(f'    mov r15d, {a}')
        out.append('    dec r15d')
        f, d = arith(a, 1, 32, True, keep_cf=CF)
    else:  # inc8
        a = rnd.choice([0x7f, 0xff, 0x0f, 3])
        out.append('    clc')
        out.append(f'    mov r15d, {a}')
        out.append('    inc r15b')
        f, d = arith(a, 1, 8, False, keep_cf=0)
    fl.apply(f, d, undefined=ALL & ~d)
    # a conditional jump out of the block whose condition is false
    jcc = pick_false_jcc(rnd, fl)
    out.append(f'    {jcc} {never}')


# ---- producers B: fused with an in-block jump, no record
def gen_B(rnd, out, fl, local):
    kind = rnd.choice(['test64', 'cmp64imm', 'test32', 'none'])
    if kind == 'none':
        return
    if kind == 'test64':
        v = rnd.choice([0, 1, 2, 0x80000000, -1])
        out.append(f'    mov rsi, {v}')
        out.append('    test rsi, rsi')
        f, d = logic(v & 0xffffffffffffffff, v & 0xffffffffffffffff, 64, 'and')
        fl.apply(f, d, undefined=AF)
        out.append(f'    jnz {local}' if (fl.val & ZF) else f'    jz {local}')
    elif kind == 'cmp64imm':
        a, b = rnd.choice([(1, 1), (0, 1), (9, 3)])
        out.append(f'    mov rsi, {a}')
        out.append(f'    cmp rsi, {b}')
        f, d = arith(a, b, 64, True)
        fl.apply(f, d)
        out.append(f'    jne {local}' if (fl.val & ZF) else f'    je {local}')
    else:
        v = rnd.choice([0, 1, 0x80000000])
        out.append(f'    mov esi, {v}')
        out.append('    test esi, esi')
        f, d = logic(v, v, 32, 'and')
        fl.apply(f, d, undefined=AF)
        out.append(f'    jnz {local}' if (fl.val & ZF) else f'    jz {local}')


# ---- direct-flag instructions C
def gen_C(rnd, out, fl, data):
    kind = rnd.choice(['ucomiss', 'comisd', 'bt', 'sahf', 'stc', 'clc', 'cmc', 'none', 'add32'])
    if kind == 'none':
        return
    if kind in ('ucomiss', 'comisd'):
        outcome = rnd.choice(['eq', 'lt', 'gt', 'un'])
        if kind == 'ucomiss':
            a, b = {'eq': ('f_one', 'f_one'), 'lt': ('f_one', 'f_two'),
                    'gt': ('f_two', 'f_one'), 'un': ('f_one', 'f_qnan')}[outcome]
            out.append(f'    movss xmm3, [rel {a}]')
            if rnd.random() < 0.5:
                out.append(f'    lea rdi, [rel {b}]')
                out.append('    ucomiss xmm3, [rdi]')
            else:
                out.append(f'    movss xmm4, [rel {b}]')
                out.append('    ucomiss xmm3, xmm4')
        else:
            a, b = {'eq': ('d_one', 'd_one'), 'lt': ('d_one', 'd_two'),
                    'gt': ('d_two', 'd_one'), 'un': ('d_one', 'd_qnan')}[outcome]
            out.append(f'    movsd xmm3, [rel {a}]')
            if rnd.random() < 0.5:
                out.append(f'    comisd xmm3, [rel {b}]')
            else:
                out.append(f'    movsd xmm4, [rel {b}]')
                out.append('    comisd xmm3, xmm4')
        f = {'eq': ZF, 'lt': CF, 'gt': 0, 'un': ZF | PF | CF}[outcome]
        fl.apply(f, ALL)
    elif kind == 'bt':
        v, bit = rnd.choice([(0x8, 3), (0x8, 2), (0xffffffff, 31), (0, 0)])
        out.append(f'    mov r8d, {v}')
        out.append(f'    bt r8d, {bit}')
        fl.apply(CF if (v >> bit) & 1 else 0, CF, undefined=ALL & ~CF)
    elif kind == 'sahf':
        ah = rnd.choice([0x02, 0xd7, 0x42, 0x81, 0x14])
        out.append(f'    mov eax, {ah << 8}')
        out.append('    sahf')
        fl.apply(ah & (SF | ZF | AF | PF | CF), SF | ZF | AF | PF | CF)
    elif kind == 'stc':
        out.append('    stc')
        fl.apply(CF, CF)
    elif kind == 'clc':
        out.append('    clc')
        fl.apply(0, CF)
    elif kind == 'cmc':
        out.append('    cmc')
        if fl.defined & CF:
            fl.apply(CF if not (fl.val & CF) else 0, CF)
        else:
            fl.apply(0, 0, undefined=CF)
    else:  # add32 (a pending-record producer sitting between B and the exit)
        a, b = rnd.choice([(1, 2), (0xffffffff, 1), (0x7fffffff, 1), (0, 0)])
        out.append(f'    mov r8d, {a}')
        out.append(f'    add r8d, {b}')
        f, d = arith(a, b, 32, False)
        fl.apply(f, d)


def pick_true_jcc(rnd, fl):
    opts = []
    if fl.defined & ZF:
        opts.append('jz' if fl.val & ZF else 'jnz')
    if fl.defined & CF:
        opts.append('jc' if fl.val & CF else 'jnc')
    if fl.defined & PF:
        opts.append('jp' if fl.val & PF else 'jnp')
    if fl.defined & SF:
        opts.append('js' if fl.val & SF else 'jns')
    if fl.defined & OF:
        opts.append('jo' if fl.val & OF else 'jno')
    if (fl.defined & (CF | ZF)) == (CF | ZF):
        opts.append('jbe' if fl.val & (CF | ZF) else 'ja')
    if (fl.defined & (SF | OF)) == (SF | OF):
        opts.append('jl' if bool(fl.val & SF) != bool(fl.val & OF) else 'jge')
    return rnd.choice(opts) if opts else None


def pick_false_jcc(rnd, fl):
    inv = {'jz': 'jnz', 'jnz': 'jz', 'jc': 'jnc', 'jnc': 'jc', 'jp': 'jnp', 'jnp': 'jp',
           'js': 'jns', 'jns': 'js', 'jo': 'jno', 'jno': 'jo', 'jbe': 'ja', 'ja': 'jbe',
           'jl': 'jge', 'jge': 'jl'}
    t = pick_true_jcc(rnd, fl)
    assert t is not None
    return inv[t]


# ---- consumers D: compute eax from the flags at the landing
def gen_D(rnd, out, fl):
    kind = rnd.choice(['setcc', 'pushf', 'adc', 'cmov', 'setcc'])
    if kind == 'setcc':
        out.append('    setz al')
        out.append('    setc bl')
        out.append('    setp cl')
        out.append('    sets dl')
        out.append('    seto r9b')
        out.append('    movzx eax, al')
        out.append('    movzx ebx, bl')
        out.append('    movzx ecx, cl')
        out.append('    movzx edx, dl')
        out.append('    movzx r9d, r9b')
        out.append('    shl ebx, 1')
        out.append('    shl ecx, 2')
        out.append('    shl edx, 3')
        out.append('    shl r9d, 4')
        out.append('    or eax, ebx')
        out.append('    or eax, ecx')
        out.append('    or eax, edx')
        out.append('    or eax, r9d')
        bits = [(ZF, 1), (CF, 2), (PF, 4), (SF, 8), (OF, 16)]
        mask = sum(b for f, b in bits if fl.defined & f)
        val = sum(b for f, b in bits if (fl.defined & f) and (fl.val & f))
        out.append(f'    and eax, {mask}')
        return val
    if kind == 'pushf':
        out.append('    pushfq')
        out.append('    pop rax')
        m = fl.defined & ALL
        out.append(f'    and eax, {m:#x}')
        return fl.val & m
    if kind == 'adc':
        out.append('    mov eax, 0')
        out.append('    adc eax, 0')
        if fl.defined & CF:
            return 1 if fl.val & CF else 0
        out.append('    mov eax, 0')
        return 0
    # cmov on ZF
    out.append('    mov eax, 0')
    out.append('    mov ecx, 1')
    out.append('    cmovz eax, ecx')
    if fl.defined & ZF:
        return 1 if fl.val & ZF else 0
    out.append('    mov eax, 0')
    return 0


def gen_case(rnd, n):
    fl = Flags()
    body = []
    land = f'c{n}_land'
    never = f'c{n}_never'
    local = f'c{n}_local'
    cont = f'c{n}_cont'
    gen_A(rnd, body, fl, never)
    gen_B(rnd, body, fl, local)
    gen_C(rnd, body, fl, None)
    # no 'call' exit: at the default BOX64_DYNAREC_SAFEFLAGS=1 the flags are, by
    # design, not guaranteed in the callee (they are at level 2)
    exit_kind = rnd.choice(['jcc', 'jmp_ind', 'jmp', 'ret'])
    if exit_kind == 'jcc':
        jcc = pick_true_jcc(rnd, fl)
        if jcc is None:
            exit_kind = 'jmp'
    if exit_kind == 'jcc':
        body.append(f'    {jcc} {land}')
        body.append('    mov eax, 0xbad1')
        body.append(f'    jmp {cont}')
    elif exit_kind == 'jmp_ind':
        body.append(f'    lea rax, [rel {land}]')
        body.append('    jmp rax')
    elif exit_kind == 'jmp':
        body.append(f'    jmp {land}')
    elif exit_kind == 'call':
        body.append(f'    call {land}')
        body.append(f'    jmp {cont}')
    else:
        body.append(f'    lea rax, [rel {land}]')
        body.append('    push rax')
        body.append('    ret')
    # the in-block target of B (never taken)
    body.append(f'{local}:')
    body.append('    mov eax, 0xbad2')
    body.append(f'    jmp {cont}')

    pad = [f'{land}:']
    expected = gen_D(rnd, pad, fl)
    if exit_kind == 'call':
        pad.append('    ret')
    else:
        pad.append(f'    jmp {cont}')
    pad.append(f'{never}:')
    pad.append('    mov eax, 0xdead')
    pad.append(f'    jmp {cont}')

    name = f'c{n}_name'
    desc = ' | '.join(l.strip() for l in body if not l.endswith(':'))[:150]
    lines = []
    lines.append(f'; ---- case {n}: {desc}')
    lines.append(f'    jmp c{n}')             # never fall into the landing pads
    lines.extend(pad)                       # backward (out-of-block) targets first
    lines.append(f'c{n}:')
    lines.append(f'    TEST_CASE {name}')
    lines.extend(body)
    lines.append(f'{cont}:')
    lines.append(f'    CHECK_EQ_32 eax, {expected:#x}')
    data = f'    {name}: db "case {n}: {desc.replace(chr(34), chr(39))}", 0'
    return lines, data


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 20261104
    rnd = random.Random(seed)
    cases = []
    datas = []
    for n in range(count):
        lines, data = gen_case(rnd, n)
        cases.append(lines)
        datas.append(data)
    print(f'; Generated by gen_flagstate_tests.py {count} {seed} - do not edit by hand.')
    print('; Flag-state hand-off cases: a producer whose jump leaves the block, a fused producer,')
    print('; a direct-flag instruction, a block exit and a consumer in the landing block.')
    print('; Build: nasm -f elf64 -o test_flagstate.o test_flagstate.asm && ld.lld -m elf_x86_64 -o bin/test_flagstate test_flagstate.o')
    print('%include "test_framework.inc"')
    print()
    print('section .data')
    for d in datas:
        print(d)
    print('    align 16')
    print('    f_one:  dd 0x3f800000')
    print('    f_two:  dd 0x40000000')
    print('    f_qnan: dd 0x7fc00000')
    print('    align 8')
    print('    d_one:  dq 0x3ff0000000000000')
    print('    d_two:  dq 0x4000000000000000')
    print('    d_qnan: dq 0x7ff8000000000000')
    print()
    print('section .text')
    print('global _start')
    print('_start:')
    print('    INIT_TESTS')
    for lines in cases:
        print('\n'.join(lines))
    print('    END_TESTS')


if __name__ == '__main__':
    main()
