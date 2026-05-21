#!/usr/bin/env bash
# tests/run_all.sh — run every tests/test_*.sh and report pass/fail.
# Set RUN_SMOKE=1 to also run tests/smoke_*.sh (slower, drives the installer end-to-end).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; FAILED=()

shopt -s nullglob
for t in "$HERE"/test_*.sh; do
  printf '\n=== Running %s ===\n' "$(basename "$t")"
  if "$t"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILED+=("$(basename "$t")")
  fi
done

if [[ "${RUN_SMOKE:-0}" == "1" ]]; then
  for t in "$HERE"/smoke_*.sh; do
    printf '\n=== Running %s ===\n' "$(basename "$t")"
    if "$t"; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1))
      FAILED+=("$(basename "$t")")
    fi
  done
fi

printf '\n--- Summary ---\n'
printf 'passed: %d\nfailed: %d\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed tests:\n'
  for t in "${FAILED[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
