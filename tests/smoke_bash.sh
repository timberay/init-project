#!/usr/bin/env bash
# smoke_bash.sh — explicit --lang bash overlay applied.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

out=$(cd "$TMP" && "$ROOT/install.sh" --lang bash --dry-run --skip-skills 2>&1)
echo "$out" | grep -q "language: bash" || fail "dry-run did not use bash"
ok "dry-run uses bash"

(cd "$TMP" && "$ROOT/install.sh" --lang bash --force --skip-skills >/dev/null 2>&1) || fail "real install exited non-zero"
grep -q "Shell Stack" "$TMP/docs/standards/STACK.md" || fail "STACK.md does not look like the bash overlay"
grep -q "Shell Tools" "$TMP/docs/standards/TOOLS.md" || fail "TOOLS.md does not look like the bash overlay"
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("shfmt") and contains("shellcheck")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference shfmt and shellcheck"
[[ -f "$TMP/.pre-commit-config.yaml" ]] || fail ".pre-commit-config.yaml not installed"
grep -q "shellcheck" "$TMP/.pre-commit-config.yaml" || fail "bash pre-commit missing shellcheck"
[[ -f "$TMP/.github/workflows/ci.yml" ]] || fail "ci.yml not installed"
grep -q "bash -n" "$TMP/.github/workflows/ci.yml" || fail "bash CI missing syntax check"
ok "real run installs bash overlay"

echo "smoke_bash.sh: ALL PASS"
