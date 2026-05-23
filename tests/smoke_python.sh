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

# Orchestrator: STATE + ADR + hooks + commands must land
[[ -f "$TMP/PROJECT_STATE.md" ]] || fail "PROJECT_STATE.md not installed"
[[ -f "$TMP/docs/decisions/README.md" ]] || fail "ADR index not installed"
[[ -f "$TMP/docs/decisions/ADR-0000-orchestrator-bootstrap.md" ]] || fail "ADR-0000 not installed"
[[ -x "$TMP/.claude/hooks/sessionstart-inject-state.sh" ]] || fail "sessionstart hook not installed (or not executable)"
[[ -x "$TMP/.claude/hooks/userpromptsubmit-remind.sh" ]] || fail "userpromptsubmit hook not installed (or not executable)"
[[ -x "$TMP/.claude/hooks/pretooluse-stale-check.sh" ]] || fail "pretooluse hook not installed (or not executable)"
[[ -f "$TMP/.claude/commands/decide.md" ]] || fail "/decide command not installed"
[[ -f "$TMP/.claude/commands/state-sync.md" ]] || fail "/state-sync command not installed"
[[ -f "$TMP/.claude/commands/supersede.md" ]] || fail "/supersede command not installed"
jq -e '.hooks.SessionStart | length >= 1' "$TMP/.claude/settings.json" >/dev/null \
  || fail "SessionStart hook not registered in merged settings.json"
ok "orchestrator files bundled"
ok "real run installs python overlay"

echo "smoke_python.sh: ALL PASS"
