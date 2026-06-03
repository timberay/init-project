#!/usr/bin/env bash
# smoke_empty.sh — empty target with no override → non-interactive mode fails fast.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Non-interactive ambiguous: should fail with mention of --lang.
set +e
out=$( cd "$TMP" && BASE_FILES_NONINTERACTIVE=1 "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "non-interactive empty dir should exit non-zero (got $rc)"
echo "$out" | grep -q -- "--lang" || fail "error message should mention --lang"
ok "non-interactive empty dir rejected with hint"

# With --lang go, it succeeds.
( cd "$TMP" && "$ROOT/install.sh" --lang go --force --skip-skills >/dev/null 2>&1 ) || fail "install with --lang go failed"
grep -q "Go" "$TMP/docs/standards/STACK.md" || fail "Go overlay not applied"
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
ok "--lang override works in empty dir"

echo "smoke_empty.sh: ALL PASS"
