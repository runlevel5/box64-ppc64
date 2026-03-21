#!/bin/bash
# run_dynarec_tests.sh - Run pre-compiled NASM dynarec tests via box64
#
# Uses pre-compiled x86_64 ELF binaries from bin/ directory.
# No NASM or cross-linker required.
#
# Usage:
#   ./run_dynarec_tests.sh                    # Run all tests
#   ./run_dynarec_tests.sh test_shifts        # Run single test
#   ./run_dynarec_tests.sh -l                 # List available tests
#   BOX64=/path/to/box64 ./run_dynarec_tests.sh  # Use custom box64

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"
BOX64="${BOX64:-$(command -v box64 2>/dev/null || echo "")}"

PASS=0
FAIL=0
SKIP=0
TOTAL=0
ERRORS=""

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' RESET=''
fi

usage() {
    echo "Usage: $0 [OPTIONS] [test_name ...]"
    echo ""
    echo "Run pre-compiled x86_64 NASM dynarec tests under box64."
    echo ""
    echo "Options:"
    echo "  -l, --list     List available tests"
    echo "  -h, --help     Show this help"
    echo ""
    echo "Environment:"
    echo "  BOX64          Path to box64 binary (default: auto-detect)"
    echo "  BOX64_LOG      box64 log level (default: 0)"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run all tests"
    echo "  $0 test_shifts test_mov     # Run specific tests"
    echo "  BOX64=./build/box64 $0      # Use local build"
    exit 0
}

list_tests() {
    echo "Available tests in ${BIN_DIR}:"
    for bin in "${BIN_DIR}"/test_*; do
        [ -x "$bin" ] || continue
        basename "$bin"
    done
    exit 0
}

run_one_test() {
    local name="$1"
    local bin="${BIN_DIR}/${name}"

    if [ ! -f "$bin" ]; then
        echo -e "${YELLOW}SKIP${RESET}: ${name} (binary not found)"
        SKIP=$((SKIP + 1))
        TOTAL=$((TOTAL + 1))
        return 0
    fi

    if [ ! -x "$bin" ]; then
        chmod +x "$bin"
    fi

    TOTAL=$((TOTAL + 1))

    # Run in interpreter mode
    local interp_output
    interp_output=$(BOX64_DYNAREC=0 BOX64_LOG=${BOX64_LOG:-0} "$BOX64" "$bin" 2>/dev/null) || true

    # Run in dynarec mode
    local dyn_output
    dyn_output=$(BOX64_DYNAREC=1 BOX64_LOG=${BOX64_LOG:-0} "$BOX64" "$bin" 2>/dev/null) || true

    # Compare
    if [ "$dyn_output" != "$interp_output" ]; then
        echo -e "${RED}FAIL${RESET}: ${BOLD}${name}${RESET} (dynarec != interpreter)"
        echo "  --- Interpreter ---"
        echo "$interp_output" | tail -1
        echo "  --- Dynarec ---"
        echo "$dyn_output" | tail -1
        echo "  --- Diff ---"
        diff <(echo "$interp_output") <(echo "$dyn_output") | head -20
        ERRORS="${ERRORS}  MISMATCH: ${name}\n"
        FAIL=$((FAIL + 1))
        return 1
    fi

    # Check if any individual test failed (look for Result line)
    local result_line
    result_line=$(echo "$dyn_output" | grep -E '^Result: ' || echo "")
    if [ -n "$result_line" ]; then
        local passed total_t
        passed=$(echo "$result_line" | sed 's/Result: \([0-9]*\)\/.*/\1/')
        total_t=$(echo "$result_line" | sed 's/Result: [0-9]*\/\([0-9]*\).*/\1/')
        if [ "$passed" != "$total_t" ]; then
            echo -e "${RED}FAIL${RESET}: ${BOLD}${name}${RESET} (${passed}/${total_t} sub-tests passed)"
            ERRORS="${ERRORS}  SUBTESTS: ${name} (${passed}/${total_t})\n"
            FAIL=$((FAIL + 1))
            return 1
        fi
        echo -e "${GREEN}PASS${RESET}: ${name} (${passed}/${total_t} sub-tests, dynarec == interpreter)"
    else
        echo -e "${GREEN}PASS${RESET}: ${name} (dynarec == interpreter)"
    fi

    PASS=$((PASS + 1))
    return 0
}

# Parse arguments
TESTS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -l|--list) list_tests ;;
        -h|--help) usage ;;
        *) TESTS+=("$1") ;;
    esac
    shift
done

# Validate
if [ ! -d "$BIN_DIR" ]; then
    echo "ERROR: Binary directory not found: ${BIN_DIR}"
    echo "Run 'nasm' compilation first or check the bin/ directory."
    exit 1
fi

if [ -z "$BOX64" ]; then
    echo "ERROR: box64 not found. Set BOX64=/path/to/box64"
    exit 1
fi

echo "Using box64: ${BOX64}"
echo "Binary dir:  ${BIN_DIR}"
echo ""

# Run tests
if [ ${#TESTS[@]} -gt 0 ]; then
    for name in "${TESTS[@]}"; do
        run_one_test "$name" || true
    done
else
    for bin in "${BIN_DIR}"/test_*; do
        [ -x "$bin" ] || [ -f "$bin" ] || continue
        name=$(basename "$bin")
        run_one_test "$name" || true
    done
fi

# Summary
echo ""
echo "========================================"
echo -e "${BOLD}SUMMARY${RESET}: ${GREEN}${PASS} passed${RESET}, ${RED}${FAIL} failed${RESET}, ${YELLOW}${SKIP} skipped${RESET} / ${TOTAL} total"
if [ $FAIL -gt 0 ]; then
    echo -e "${RED}FAILURES:${RESET}"
    echo -e "$ERRORS"
fi
echo "========================================"

exit $FAIL
