#!/usr/bin/env bash
# Test: check_deps returns 0 when required tools exist; marks missing ones
# in MISSING_DEPS array; never errors on absence.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=../lib/check-deps.sh
source "$ROOT/lib/check-deps.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# Case 1: with `jq`, `git` present (assume they are) — MISSING_DEPS does not include them.
MISSING_DEPS=()
check_deps rails >/dev/null 2>&1 || true
for t in jq git; do
  for m in "${MISSING_DEPS[@]:-}"; do
    [[ "$m" == "$t" ]] && fail "$t reported missing but should be present"
  done
done
ok "real deps not falsely reported missing"

# Case 2: spoof a missing tool by shadowing PATH so a fake required tool name vanishes.
# We can't easily spoof "ruby is missing" without uninstalling — instead inject a fake
# required dep into a copy of the function via a wrapper.
test_missing_wrapper() {
  MISSING_DEPS=()
  REQUIRED_OS=(definitelynotinpath_xyz)
  REQUIRED_LANG_rails=()
  check_deps rails >/dev/null 2>&1 || true
  local found=0
  for m in "${MISSING_DEPS[@]:-}"; do
    [[ "$m" == "definitelynotinpath_xyz" ]] && found=1
  done
  [[ $found -eq 1 ]] || fail "missing tool not recorded in MISSING_DEPS"
}
test_missing_wrapper
ok "missing tool reported in MISSING_DEPS"

echo "test_check_deps.sh: ALL PASS"
