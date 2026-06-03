#!/usr/bin/env bash
# smoke_empty.sh — empty target with no override → bash overlay by default.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Non-interactive empty dir should default to bash and remain dry-run only.
out=$( cd "$TMP" && BASE_FILES_NONINTERACTIVE=1 "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
echo "$out" | grep -q "language: bash" || fail "dry-run empty dir did not default to bash"
[[ ! -f "$TMP/CLAUDE.md" ]] || fail "dry-run wrote CLAUDE.md"
ok "non-interactive empty dir defaults to bash"

# Empty dir real run also defaults to bash.
( cd "$TMP" && "$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 ) || fail "install with default bash failed"
grep -q "Shell Stack" "$TMP/docs/standards/STACK.md" || fail "bash overlay not applied"
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("shellcheck")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference shellcheck"
ok "default bash overlay installed"

[[ -f "$TMP/.agents/skills/push2gh/SKILL.md" ]] || fail "push2gh skill not installed"
head -2 "$TMP/.agents/skills/push2gh/SKILL.md" | grep -q "name: push2gh" || fail "push2gh SKILL.md missing expected frontmatter"
[[ -L "$TMP/.claude/skills" ]] || fail ".claude/skills symlink not installed"
ok "push2gh skill bundled"

# Cross-agent config files must land.
[[ -f "$TMP/AGENTS.md" ]] || fail "AGENTS.md not installed"
[[ -f "$TMP/opencode.json" ]] || fail "opencode.json not installed"
[[ -f "$TMP/.codex/hooks.json" ]] || fail ".codex/hooks.json not installed"
jq -e '.hooks.PreToolUse | map(.hooks[].command) | flatten | any(test("security-check.sh"))' "$TMP/.codex/hooks.json" >/dev/null \
  || fail "Codex hooks should reference security-check.sh"
jq -e '.instructions | index("AGENTS.md")' "$TMP/opencode.json" >/dev/null \
  || fail "opencode.json should include AGENTS.md instructions"
ok "Codex/opencode config bundled"

# Orchestrator: STATE + ADR + hooks + commands must land
[[ -f "$TMP/PROJECT_STATE.md" ]] || fail "PROJECT_STATE.md not installed"
TODAY="$(date +%Y-%m-%d)"
grep -q "^> Lifecycle Stage: Setup (since ${TODAY})$" "$TMP/PROJECT_STATE.md" \
  || fail "PROJECT_STATE.md missing seeded 'Lifecycle Stage: Setup (since ${TODAY})' line"
ok "PROJECT_STATE.md seeded with Lifecycle Stage line dated today"
[[ -f "$TMP/docs/decisions/README.md" ]] || fail "ADR index not installed"
[[ -f "$TMP/docs/decisions/ADR-0000-orchestrator-bootstrap.md" ]] || fail "ADR-0000 not installed"
[[ -x "$TMP/.agent-hooks/sessionstart-inject-state.sh" ]] || fail "sessionstart hook not installed (or not executable)"
[[ -x "$TMP/.agent-hooks/userpromptsubmit-remind.sh" ]] || fail "userpromptsubmit hook not installed (or not executable)"
[[ -x "$TMP/.agent-hooks/pretooluse-stale-check.sh" ]] || fail "pretooluse hook not installed (or not executable)"
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
ok "empty dir bootstrap works"

echo "smoke_empty.sh: ALL PASS"
