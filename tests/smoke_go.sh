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
jq -e '.hooks.UserPromptSubmit | map(.hooks[].command) | flatten | any(test("userpromptsubmit-remind.sh"))' "$TMP/.claude/settings.json" >/dev/null \
  || fail "userpromptsubmit-remind.sh not registered in merged UserPromptSubmit"
jq -e '.hooks.PreToolUse | map(.hooks[].command) | flatten | any(test("pretooluse-stale-check.sh"))' "$TMP/.claude/settings.json" >/dev/null \
  || fail "pretooluse-stale-check.sh not registered in merged PreToolUse"
ok "orchestrator files bundled"
ok "real run installs go overlay"

[[ -f "$TMP/.editorconfig" ]] || fail ".editorconfig not installed"
grep -q "^root = true" "$TMP/.editorconfig" || fail ".editorconfig missing 'root = true'"
ok ".editorconfig bundled"

echo "smoke_go.sh: ALL PASS"
