#!/bin/bash
# run_tests.sh - Build and run all NASM dynarec tests
# Usage: ./run_tests.sh [test_name]
#   Run all tests:     ./run_tests.sh
#   Run single test:   ./run_tests.sh test_bit_extract

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOX64="${BOX64:-${HOME}/box64/build/box64}"
BUILD_DIR="${TMPDIR:-/tmp}"
PASS=0
FAIL=0
TOTAL=0
ERRORS=""

build_test() {
    local name="$1"
    local src="${SCRIPT_DIR}/${name}.asm"
    local obj="${BUILD_DIR}/${name}.o"
    local bin="${BUILD_DIR}/${name}"
    local prebuilt="${SCRIPT_DIR}/bin/${name}"

    if [ ! -f "$src" ]; then
        echo "ERROR: $src not found"
        return 1
    fi

    # Detect 32-bit tests by name prefix
    local nasm_fmt="elf64"
    local ld_emul=""
    if [[ "$name" == test_32bit_* ]]; then
        nasm_fmt="elf32"
        ld_emul="-m elf_i386"
    fi

    nasm -f "$nasm_fmt" -I "${SCRIPT_DIR}/" "$src" -o "$obj" 2>&1
    if [ $? -ne 0 ]; then
        echo "WARN: nasm failed for $name, trying pre-built binary"
        if [ -x "$prebuilt" ]; then
            cp "$prebuilt" "$bin"
            return 0
        fi
        echo "ERROR: no pre-built binary for $name"
        return 1
    fi

    x86_64-linux-gnu-ld $ld_emul "$obj" -o "$bin" 2>&1
    if [ $? -ne 0 ]; then
        # Try native ld as fallback (works on x86_64 hosts)
        ld $ld_emul "$obj" -o "$bin" 2>&1
        if [ $? -ne 0 ]; then
            echo "WARN: link failed for $name, trying pre-built binary"
            if [ -x "$prebuilt" ]; then
                cp "$prebuilt" "$bin"
                return 0
            fi
            echo "ERROR: no pre-built binary for $name"
            return 1
        fi
    fi

    return 0
}

run_test() {
    local name="$1"
    local bin="${BUILD_DIR}/${name}"
    local mode="$2"  # "dynarec" or "interp"

    if [ "$mode" = "interp" ]; then
        BOX64_DYNAREC=0 "$BOX64" "$bin" 2>/dev/null
    else
        BOX64_DYNAREC=1 "$BOX64" "$bin" 2>/dev/null
    fi
    return $?
}

run_single_test() {
    local name="$1"
    echo "========================================"
    echo "Building: $name"
    echo "========================================"

    build_test "$name"
    if [ $? -ne 0 ]; then
        ERRORS="${ERRORS}  BUILD FAILED: ${name}\n"
        FAIL=$((FAIL + 1))
        TOTAL=$((TOTAL + 1))
        return 1
    fi

    echo "--- Dynarec mode ---"
    local dyn_output
    dyn_output=$(run_test "$name" "dynarec")
    local dyn_rc=$?
    echo "$dyn_output"

    echo "--- Interpreter mode ---"
    local interp_output
    interp_output=$(run_test "$name" "interp")
    local interp_rc=$?
    echo "$interp_output"

    TOTAL=$((TOTAL + 1))

    # Compare outputs
    if [ "$dyn_output" != "$interp_output" ]; then
        echo "*** MISMATCH: dynarec vs interpreter output differs! ***"
        echo "--- Diff ---"
        diff <(echo "$dyn_output") <(echo "$interp_output")
        ERRORS="${ERRORS}  MISMATCH: ${name}\n"
        FAIL=$((FAIL + 1))
        return 1
    elif [ $dyn_rc -ne 0 ]; then
        echo "*** FAIL: test returned non-zero exit code ***"
        ERRORS="${ERRORS}  FAILED: ${name}\n"
        FAIL=$((FAIL + 1))
        return 1
    else
        echo "==> PASS (dynarec == interpreter, all checks passed)"
        PASS=$((PASS + 1))
        return 0
    fi
}

# Main
if [ -n "$1" ]; then
    # Run single test
    run_single_test "$1"
else
    # Run all tests
    for src in "${SCRIPT_DIR}"/test_*.asm; do
        name=$(basename "$src" .asm)
        # Skip the framework include file
        [ "$name" = "test_framework" ] && continue
        run_single_test "$name"
        echo ""
    done
fi

echo ""
echo "========================================"
echo "SUMMARY: ${PASS}/${TOTAL} test suites passed"
if [ $FAIL -gt 0 ]; then
    echo "FAILURES:"
    echo -e "$ERRORS"
fi
echo "========================================"

exit $FAIL
