#!/usr/bin/env bash
# tests/run_all.sh — run every tests/test_*.sh and report pass/fail.
#
# Set RUN_SMOKE=1 to also run tests/smoke_*.sh (drives install.sh against empty
# dirs with only manifest files — fast, no toolchain required).
#
# Set RUN_E2E=1 to also run tests/e2e_*.sh (drives install.sh against real
# framework projects: rails new / uv init / go mod init. Slower; requires the
# matching toolchain + pre-commit. Missing toolchain ⇒ SKIP, not FAIL.
# Use STRICT=1 to promote SKIP to FAIL.).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; SKIP=0; FAILED=(); SKIPPED=()

run_one() {
  local t="$1"
  printf '\n=== Running %s ===\n' "$(basename "$t")"
  "$t"
  local rc=$?
  case "$rc" in
    0)  PASS=$((PASS+1)) ;;
    77) SKIP=$((SKIP+1)); SKIPPED+=("$(basename "$t")") ;;
    *)  FAIL=$((FAIL+1)); FAILED+=("$(basename "$t")") ;;
  esac
}

shopt -s nullglob
for t in "$HERE"/test_*.sh; do run_one "$t"; done

if [[ "${RUN_SMOKE:-0}" == "1" ]]; then
  for t in "$HERE"/smoke_*.sh; do run_one "$t"; done
fi

if [[ "${RUN_E2E:-0}" == "1" ]]; then
  for t in "$HERE"/e2e_*.sh; do run_one "$t"; done
fi

printf '\n--- Summary ---\n'
printf 'passed: %d\nfailed: %d\nskipped: %d\n' "$PASS" "$FAIL" "$SKIP"
if [[ "$SKIP" -gt 0 ]]; then
  printf 'skipped tests (missing toolchain — set STRICT=1 to fail instead):\n'
  for t in "${SKIPPED[@]}"; do printf '  - %s\n' "$t"; done
fi
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed tests:\n'
  for t in "${FAILED[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
