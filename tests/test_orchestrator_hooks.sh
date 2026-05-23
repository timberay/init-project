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

echo "test_orchestrator_hooks.sh: ALL PASS"
