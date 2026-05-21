#!/usr/bin/env bash
# smoke_empty.sh — empty target with no override → non-interactive mode fails fast.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Non-interactive ambiguous: should fail with mention of --lang.
set +e
out=$( cd "$TMP" && BASE_FILES_NONINTERACTIVE=1 "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "non-interactive empty dir should exit non-zero (got $rc)"
echo "$out" | grep -q -- "--lang" || fail "error message should mention --lang"
ok "non-interactive empty dir rejected with hint"

# With --lang go, it succeeds.
( cd "$TMP" && "$ROOT/install.sh" --lang go --force --skip-skills >/dev/null 2>&1 ) || fail "install with --lang go failed"
grep -q "Go" "$TMP/docs/standards/STACK.md" || fail "Go overlay not applied"
ok "--lang override works in empty dir"

echo "smoke_empty.sh: ALL PASS"
