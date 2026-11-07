#!/usr/bin/env bash
#
# gen-distro-patch.sh — produce a downstream patch for Linux distro packagers.
#
# Diffs a base version against the current HEAD and writes a single .patch
# file containing only the changes that matter for packaging. Changes that
# packagers don't need (documentation, tests, CI config, editor/AI dotfiles)
# are excluded so the patch stays focused on buildable source.
#
# Usage:
#   tools/gen-distro-patch.sh [VERSION] [-o OUTPUT.patch]
#
#   tools/gen-distro-patch.sh 0.4.2          # diff v0.4.2..HEAD
#   tools/gen-distro-patch.sh v0.4.2         # same (explicit tag)
#   tools/gen-distro-patch.sh                # diff main..HEAD (no version)
#   tools/gen-distro-patch.sh 0.4.2 -o x.patch
#
# Extra paths can be excluded via the EXTRA_EXCLUDES env var (space separated),
# e.g.  EXTRA_EXCLUDES="debian/ pkgbuilds/" tools/gen-distro-patch.sh 0.4.2
#
set -euo pipefail

# --- remember where we were invoked, then work from the repo root ----------
INVOKE_DIR="$PWD"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "error: not inside a git repository" >&2
    exit 1
}
cd "$REPO_ROOT"

# --- parse arguments -------------------------------------------------------
VERSION=""
OUTPUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output) OUTPUT="$2"; shift 2 ;;
        -h|--help)   sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)          echo "error: unknown option: $1" >&2; exit 1 ;;
        *)           if [[ -z "$VERSION" ]]; then VERSION="$1"; shift
                     else echo "error: unexpected argument: $1" >&2; exit 1; fi ;;
    esac
done

# --- resolve the base ref to diff against ----------------------------------
resolve_ref() { git rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1; }

BASE=""
if [[ -n "$VERSION" ]]; then
    # Accept "0.4.2" or "v0.4.2"; tags in this repo are v-prefixed.
    for cand in "$VERSION" "v$VERSION"; do
        if resolve_ref "refs/tags/$cand"; then BASE="$cand"; break; fi
    done
    if [[ -z "$BASE" ]]; then
        echo "error: no tag matching '$VERSION' or 'v$VERSION'" >&2
        echo "hint: available tags:" >&2
        git tag --list 'v*' | tail -n 10 | sed 's/^/  /' >&2
        exit 1
    fi
else
    # No version given: diff against the main branch.
    for cand in main origin/main upstream/main; do
        if resolve_ref "$cand"; then BASE="$cand"; break; fi
    done
    if [[ -z "$BASE" ]]; then
        echo "error: could not find a 'main' branch (tried main, origin/main, upstream/main)" >&2
        exit 1
    fi
fi

# --- paths that are not useful to packagers --------------------------------
# git pathspecs: one positive ('.') plus negative ':(exclude)' entries.
EXCLUDES=(
    ':(exclude)docs/'                 # documentation
    ':(exclude)tests/'                # test suite + prebuilt test binaries
    ':(exclude)tests32/'
    ':(exclude).github/'              # CI workflows
    ':(exclude).gemini/'              # assistant/editor config
    ':(exclude,glob)**/*.md'          # README, CHANGELOG, CONTRIBUTING, etc.
    ':(exclude).clang-format'
    ':(exclude).gitignore'
    ':(exclude).gitattributes'
    ':(exclude).editorconfig'
)
# Append any caller-provided extra excludes.
if [[ -n "${EXTRA_EXCLUDES:-}" ]]; then
    for p in $EXTRA_EXCLUDES; do EXCLUDES+=(":(exclude)$p"); done
fi

# --- default output filename -----------------------------------------------
if [[ -z "$OUTPUT" ]]; then
    safe_base="${BASE//\//-}"        # origin/main -> origin-main
    OUTPUT="box64-${safe_base}-downstream.patch"
fi
# Resolve OUTPUT relative to where the user invoked the script.
case "$OUTPUT" in
    /*) : ;;                          # absolute, leave as-is
    *)  OUTPUT="$INVOKE_DIR/$OUTPUT" ;;
esac

# --- generate the patch ----------------------------------------------------
git diff --no-color "$BASE" HEAD -- . "${EXCLUDES[@]}" > "$OUTPUT"

# --- report ----------------------------------------------------------------
head_desc="$(git describe --tags --always --dirty 2>/dev/null || git rev-parse --short HEAD)"
if [[ ! -s "$OUTPUT" ]]; then
    echo "No packaging-relevant changes between $BASE and HEAD ($head_desc)."
    echo "(empty patch written to $OUTPUT)"
    exit 0
fi

echo "Base:   $BASE"
echo "Head:   $head_desc"
echo "Patch:  $OUTPUT"
echo
echo "Included changes (summary):"
git diff --stat "$BASE" HEAD -- . "${EXCLUDES[@]}" | sed 's/^/  /'

# Warn if any binary files slipped through (patch(1) cannot apply those).
if grep -q '^Binary files ' "$OUTPUT"; then
    echo
    echo "warning: the patch references binary files (git-style binary diff);" >&2
    echo "         'patch -p1' cannot apply these — use 'git apply' or add an" >&2
    echo "         exclude for them via EXTRA_EXCLUDES." >&2
fi
