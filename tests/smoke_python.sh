#!/usr/bin/env bash
# smoke_python.sh — pyproject.toml present → python overlay applied.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
touch "$TMP/pyproject.toml"

out=$( cd "$TMP" && "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
echo "$out" | grep -q "language: python" || fail "dry-run did not detect python"
ok "dry-run detects python"

( cd "$TMP" && "$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 ) || fail "real install exited non-zero"
[[ -f "$TMP/docs/standards/STACK.md" ]] || fail "Python STACK.md missing"
grep -q "Python" "$TMP/docs/standards/STACK.md" || fail "STACK.md does not look like the Python overlay"
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("ruff")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference ruff"
[[ -f "$TMP/.claude/skills/push2gh/SKILL.md" ]] || fail "push2gh skill not installed"
head -2 "$TMP/.claude/skills/push2gh/SKILL.md" | grep -q "name: push2gh" || fail "push2gh SKILL.md missing expected frontmatter"
ok "push2gh skill bundled"
ok "real run installs python overlay"

echo "smoke_python.sh: ALL PASS"
