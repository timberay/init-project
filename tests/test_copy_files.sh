#!/usr/bin/env bash
# Test: copy_files merges common/ and langs/<lang>/ into a target dir, backs
# up existing files with a timestamp suffix, and respects --force semantics.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=../lib/copy-files.sh
source "$ROOT/lib/copy-files.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build a fake common/ and rails/
mkdir -p "$TMP/src/common/docs/standards" "$TMP/src/langs/rails/docs/standards"
echo "common-rules" > "$TMP/src/common/docs/standards/RULES.md"
echo "rails-stack"  > "$TMP/src/langs/rails/docs/standards/STACK.md"

# Case 1: copy into empty target
mkdir "$TMP/dst1"
copy_files "$TMP/src/common" "$TMP/src/langs/rails" "$TMP/dst1" 1 0  # force=1, dry=0
[[ -f "$TMP/dst1/docs/standards/RULES.md" ]] || fail "RULES.md not copied"
[[ -f "$TMP/dst1/docs/standards/STACK.md" ]] || fail "STACK.md not copied"
ok "fresh copy"

# Case 2: copy into target with conflict; force=1 should back up existing
mkdir -p "$TMP/dst2/docs/standards"
echo "old-rules" > "$TMP/dst2/docs/standards/RULES.md"
copy_files "$TMP/src/common" "$TMP/src/langs/rails" "$TMP/dst2" 1 0
[[ -f "$TMP/dst2/docs/standards/RULES.md" ]] || fail "RULES.md not present after overwrite"
grep -q "common-rules" "$TMP/dst2/docs/standards/RULES.md" || fail "RULES.md not overwritten"
ls "$TMP/dst2/docs/standards/" | grep -E "RULES.md.bak.[0-9]" >/dev/null || fail "no backup file created"
ok "conflict overwrites with backup"

# Case 3: dry run does not write anything
mkdir "$TMP/dst3"
copy_files "$TMP/src/common" "$TMP/src/langs/rails" "$TMP/dst3" 1 1  # force=1, dry=1
[[ ! -f "$TMP/dst3/docs/standards/RULES.md" ]] || fail "dry-run wrote a file"
ok "dry-run is read-only"

echo "test_copy_files.sh: ALL PASS"
