#!/usr/bin/env bash
# e2e_go.sh — Real-framework end-to-end on a fresh Go module.
#
# Flow: go mod init → install.sh → pre-commit install → first commit
#       → intentional oversize-file violation (must be blocked)
#       → fix → clean commit (must succeed)
#       → PROJECT_STATE drift hook warns on 10-day-old state file.
#
# Exit codes: 0 PASS · 1 FAIL · 77 SKIP (missing toolchain; override with STRICT=1)
# Env: KEEP_SANDBOX=1 keeps the tmp dir for inspection.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }
skip() { echo "SKIP: $1" >&2; [[ "${STRICT:-0}" -eq 1 ]] && exit 1; exit 77; }

# --- precheck ---
command -v go         >/dev/null 2>&1 || skip "go not found (https://go.dev/dl/)"
command -v git        >/dev/null 2>&1 || skip "git not found"
command -v pre-commit >/dev/null 2>&1 || skip "pre-commit not found (pipx install pre-commit)"

# --- sandbox ---
TMP="$(mktemp -d -t init-project-e2e-go.XXXXXX)"
cleanup() {
  if [[ "${KEEP_SANDBOX:-0}" -eq 1 ]]; then
    echo "sandbox kept: $TMP" >&2
  else
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT
echo "sandbox: $TMP"

# --- framework init ---
cd "$TMP"
go mod init example.com/sandbox >/dev/null 2>&1 || fail "go mod init failed"
cat >main.go <<'GO'
package main

import "fmt"

func main() {
	fmt.Println("hello")
}
GO
[[ -f go.mod ]] || fail "go.mod missing after init"
ok "go mod init scaffolded a minimal Go module"

# --- install.sh ---
"$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 || fail "install.sh exited non-zero"
[[ -f CLAUDE.md ]]                || fail "install.sh did not place CLAUDE.md"
[[ -f PROJECT_STATE.md ]]         || fail "install.sh did not place PROJECT_STATE.md"
[[ -f .pre-commit-config.yaml ]]  || fail "install.sh did not place .pre-commit-config.yaml"
[[ -d docs/decisions ]]           || fail "install.sh did not place docs/decisions/"
ok "install.sh placed common + go overlay on top of Go module"

# --- git init + pre-commit install ---
git init -q
git -c user.email=test@test -c user.name=test add . >/dev/null
# go overlay declares golangci-lint as a system hook; skip it for hook bootstrap so
# the test does not require golangci-lint on the host. The other go-fmt / go-vet /
# go-mod-tidy hooks still run and gate commits.
SKIP=golangci-lint pre-commit install --install-hooks >/dev/null 2>&1 \
  || fail "pre-commit install failed (network? hook dependencies missing?)"
ok "pre-commit hooks installed (golangci-lint skipped — system hook)"

# --- ADR-0001 invariant: bootstrap commit must succeed ---
SKIP=golangci-lint git -c user.email=test@test -c user.name=test commit -q -m "Bootstrap from base-files" \
  || fail "bootstrap commit failed (ADR-0001 regression)"
ok "ADR-0001: bootstrap commit succeeds"

# --- intentional violation: oversize file (>1MB) ---
dd if=/dev/zero of=oversize.bin bs=1024 count=1100 status=none
git add oversize.bin
set +e
SKIP=golangci-lint git -c user.email=test@test -c user.name=test commit -q -m "should be blocked" 2>/dev/null
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "pre-commit failed to block oversize file"
ok "pre-commit blocks oversize file (check-added-large-files)"

# --- fix + clean commit succeeds ---
git rm -f oversize.bin >/dev/null 2>&1
echo "scratch" > scratch.md
git add scratch.md
SKIP=golangci-lint git -c user.email=test@test -c user.name=test commit -q -m "scratch" \
  || fail "clean commit was rejected after fix"
ok "clean commit succeeds after removing oversize file"

# --- PROJECT_STATE drift hook ---
touch -d "10 days ago" PROJECT_STATE.md
out=$(printf '%s' '{"tool_name":"Edit"}' | bash .claude/hooks/pretooluse-stale-check.sh 2>&1)
echo "$out" | grep -q "stale" \
  || fail "drift hook did not warn on 10-day-old PROJECT_STATE.md (output: $out)"
ok "drift hook warns on stale PROJECT_STATE.md"

echo "e2e_go.sh: ALL PASS"
