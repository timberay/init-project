#!/usr/bin/env bash
# smoke_rails.sh — Gemfile present → rails overlay applied.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
touch "$TMP/Gemfile"

# Phase 1: dry-run reports rails and writes nothing.
out=$( cd "$TMP" && "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
echo "$out" | grep -q "language: rails" || fail "dry-run did not detect rails"
[[ ! -f "$TMP/CLAUDE.md" ]] || fail "dry-run wrote CLAUDE.md"
[[ ! -f "$TMP/.claude/settings.json" ]] || fail "dry-run wrote settings.json"
ok "dry-run detects rails and writes nothing"

# Phase 2: real run writes files and a Rails-specific hook lives in settings.json.
( cd "$TMP" && "$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 ) || fail "real install exited non-zero"
[[ -f "$TMP/CLAUDE.md" ]] || fail "CLAUDE.md missing after install"
[[ -f "$TMP/docs/standards/STACK.md" ]] || fail "Rails STACK.md missing"
grep -q "Rails" "$TMP/docs/standards/STACK.md" || fail "STACK.md does not look like the Rails overlay"
jq -e '.hooks.PreToolUse | length >= 1' "$TMP/.claude/settings.json" >/dev/null \
  || fail "merged settings.json should have at least 1 PreToolUse entry (orchestrator stale-check)"
[[ -f "$TMP/.agents/skills/push2gh/SKILL.md" ]] || fail "push2gh skill not installed"
head -2 "$TMP/.agents/skills/push2gh/SKILL.md" | grep -q "name: push2gh" || fail "push2gh SKILL.md missing expected frontmatter"
[[ -L "$TMP/.claude/skills" ]] || fail ".claude/skills symlink not installed"
ok "push2gh skill bundled"

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
ok "real run installs rails overlay"

[[ -f "$TMP/.editorconfig" ]] || fail ".editorconfig not installed"
grep -q "^root = true" "$TMP/.editorconfig" || fail ".editorconfig missing 'root = true'"
ok ".editorconfig bundled"

[[ -f "$TMP/.gitignore" ]] || fail "Rails .gitignore not installed"
head -3 "$TMP/.gitignore" | grep -q "github/gitignore" || fail ".gitignore is not the github/gitignore-sourced overlay"
grep -qE "^/log/\*" "$TMP/.gitignore" || fail "Rails .gitignore missing /log/*"
ok "Rails .gitignore bundled"

jq -e '.hooks.PreToolUse | map(.hooks[].command) | flatten | any(test("security-check.sh"))' "$TMP/.claude/settings.json" >/dev/null \
  || fail "security-check.sh not registered for Bash guardrail"
! jq -e '.hooks.PreToolUse | map(.hooks[].command) | flatten | any(test("rails test|rubocop|pre-commit"))' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PreToolUse should not run quality gates (ADR-0001: gating moved to pre-commit/CI)"
ok "ADR-0001: no PreToolUse quality gate present"

[[ -f "$TMP/.pre-commit-config.yaml" ]] || fail ".pre-commit-config.yaml not installed"
[[ -f "$TMP/.github/workflows/ci.yml" ]] || fail "ci.yml not installed"
ok ".pre-commit-config.yaml + ci.yml bundled"

# ADR-0001: empty-project bootstrap commit must succeed (this was the bug that motivated the migration)
( cd "$TMP" && git init -q && git add . && git -c user.email=test@test -c user.name=test commit -q -m "Bootstrap from base-files" ) \
  || fail "empty-project bootstrap commit failed (ADR-0001 regression)"
ok "empty-project bootstrap commit exits 0"

echo "smoke_rails.sh: ALL PASS"
