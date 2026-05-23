#!/usr/bin/env bash
# tests/test_orchestrator_hooks.sh — unit tests for the orchestrator hook scripts.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

SS="$ROOT/common/.claude/hooks/sessionstart-inject-state.sh"

# --- sessionstart-inject-state.sh ---

# Case 1: no PROJECT_STATE.md and no docs/decisions/README.md → bootstrap notice
TMP="$(mktemp -d)"
out="$(cd "$TMP" && bash "$SS")"
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null \
  || fail "sessionstart: missing hookEventName"
echo "$out" | jq -e '.hookSpecificOutput.additionalContext | test("not initialized"; "i")' >/dev/null \
  || fail "sessionstart: missing bootstrap notice when nothing exists"
rm -rf "$TMP"
ok "sessionstart: bootstrap notice when STATE absent"

# Case 2: PROJECT_STATE.md present → its content is injected
TMP="$(mktemp -d)"
printf '# PROJECT_STATE\n\nCurrent Phase: 3\n' > "$TMP/PROJECT_STATE.md"
out="$(cd "$TMP" && bash "$SS")"
echo "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "Current Phase: 3" \
  || fail "sessionstart: STATE content not in additionalContext"
rm -rf "$TMP"
ok "sessionstart: STATE content injected when present"

# Case 3: docs/decisions/README.md present → its content is injected too
TMP="$(mktemp -d)"
mkdir -p "$TMP/docs/decisions"
printf '# Decisions\n\n| 0000 | foo | Accepted |\n' > "$TMP/docs/decisions/README.md"
out="$(cd "$TMP" && bash "$SS")"
echo "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "0000" \
  || fail "sessionstart: ADR index not in additionalContext"
rm -rf "$TMP"
ok "sessionstart: ADR index injected when present"

# --- userpromptsubmit-remind.sh ---

UP="$ROOT/common/.claude/hooks/userpromptsubmit-remind.sh"

# Case 1: prompt with "이전에" Korean keyword → reminder emitted
out="$(echo '{"prompt":"이전에 결정한 DB 선택 다시 보고 싶어"}' | bash "$UP")"
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null \
  || fail "userpromptsubmit (ko): no hookEventName"
echo "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "docs/decisions" \
  || fail "userpromptsubmit (ko): reminder missing pointer to docs/decisions"
ok "userpromptsubmit: reminds on Korean prior-decision keyword"

# Case 2: prompt with "why did we" English keyword → reminder emitted
out="$(echo '{"prompt":"why did we pick Redis here?"}' | bash "$UP")"
echo "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "docs/decisions" \
  || fail "userpromptsubmit (en): reminder missing"
ok "userpromptsubmit: reminds on English prior-decision keyword"

# Case 3: ordinary prompt → silent (no output)
out="$(echo '{"prompt":"add a button to the login page"}' | bash "$UP")"
[[ -z "$out" ]] || fail "userpromptsubmit: should be silent on ordinary prompt, got: $out"
ok "userpromptsubmit: silent on non-matching prompt"

# Case 4: empty payload → silent
out="$(echo '{}' | bash "$UP")"
[[ -z "$out" ]] || fail "userpromptsubmit: should be silent on empty prompt, got: $out"
ok "userpromptsubmit: silent on empty payload"

echo "test_orchestrator_hooks.sh: ALL PASS"
