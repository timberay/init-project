#!/usr/bin/env bash
# smoke_go.sh — go.mod present → go overlay applied.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
touch "$TMP/go.mod"

out=$( cd "$TMP" && "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
echo "$out" | grep -q "language: go" || fail "dry-run did not detect go"
ok "dry-run detects go"

( cd "$TMP" && "$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 ) || fail "real install exited non-zero"
grep -q "Go" "$TMP/docs/standards/STACK.md" || fail "STACK.md does not look like the Go overlay"
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("gofmt")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference gofmt"
[[ -f "$TMP/.claude/skills/push2gh/SKILL.md" ]] || fail "push2gh skill not installed"
head -2 "$TMP/.claude/skills/push2gh/SKILL.md" | grep -q "name: push2gh" || fail "push2gh SKILL.md missing expected frontmatter"
ok "push2gh skill bundled"
ok "real run installs go overlay"

echo "smoke_go.sh: ALL PASS"
