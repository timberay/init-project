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

# Case 5: bare "earlier" without decision context → silent (false positive guard)
out="$(echo '{"prompt":"I updated this function earlier today, is it correct?"}' | bash "$UP")"
[[ -z "$out" ]] || fail "userpromptsubmit: bare 'earlier' should not trigger, got: $out"
ok "userpromptsubmit: silent on bare 'earlier' without decision context"

# Case 6: bare "previously" without decision context → silent
out="$(echo '{"prompt":"I previously wrote this code but now want to refactor it"}' | bash "$UP")"
[[ -z "$out" ]] || fail "userpromptsubmit: bare 'previously' should not trigger, got: $out"
ok "userpromptsubmit: silent on bare 'previously' without decision context"

# Case 7: malformed JSON → silent, exit 0 (not a blocking error)
set +e
out="$(printf 'not json at all' | bash "$UP" 2>/dev/null)"
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "userpromptsubmit: malformed JSON should exit 0, got rc=$rc"
[[ -z "$out" ]] || fail "userpromptsubmit: malformed JSON should be silent, got: $out"
ok "userpromptsubmit: silent + exit 0 on malformed JSON"

# --- pretooluse-stale-check.sh ---

PT="$ROOT/common/.claude/hooks/pretooluse-stale-check.sh"

# Case 1: non-target tool (e.g. Read) → silent
out="$(echo '{"tool_name":"Read"}' | bash "$PT" 2>&1)"
[[ -z "$out" ]] || fail "pretooluse: should be silent for Read, got: $out"
ok "pretooluse: silent for non-target tool"

# Case 2: target tool, no PROJECT_STATE.md → stderr warning, exit 0
TMP="$(mktemp -d)"
err="$(cd "$TMP" && echo '{"tool_name":"Edit"}' | bash "$PT" 2>&1 >/dev/null)"
echo "$err" | grep -q "missing" \
  || fail "pretooluse: missing-file warning not emitted (got: $err)"
rm -rf "$TMP"
ok "pretooluse: warns when PROJECT_STATE.md missing"

# Case 3: target tool, fresh PROJECT_STATE.md → silent
TMP="$(mktemp -d)"
touch "$TMP/PROJECT_STATE.md"
out="$(cd "$TMP" && echo '{"tool_name":"Edit"}' | bash "$PT" 2>&1)"
[[ -z "$out" ]] || fail "pretooluse: should be silent on fresh STATE, got: $out"
rm -rf "$TMP"
ok "pretooluse: silent on fresh PROJECT_STATE.md"

# Cross-platform helper for setting mtime N days in the past
back_date_file() {
  local file="$1" days="$2"
  if touch -d "${days} days ago" "$file" 2>/dev/null; then
    return 0
  fi
  # BSD fallback (macOS)
  local stamp
  stamp="$(date -v-${days}d +%Y%m%d%H%M 2>/dev/null || date -d "${days} days ago" +%Y%m%d%H%M)"
  touch -t "$stamp" "$file"
}

# Case 4: target tool, stale PROJECT_STATE.md (>7 days) → warning
TMP="$(mktemp -d)"
touch "$TMP/PROJECT_STATE.md"
back_date_file "$TMP/PROJECT_STATE.md" 10
err="$(cd "$TMP" && echo '{"tool_name":"Edit"}' | bash "$PT" 2>&1 >/dev/null)"
echo "$err" | grep -qE 'stale|days' \
  || fail "pretooluse: stale warning not emitted (got: $err)"
rm -rf "$TMP"
ok "pretooluse: warns when PROJECT_STATE.md is >7 days stale"

# Case 5: STATE_STALE_DAYS=1 override → warns on 2-day-old file
TMP="$(mktemp -d)"
touch "$TMP/PROJECT_STATE.md"
back_date_file "$TMP/PROJECT_STATE.md" 2
err="$(cd "$TMP" && echo '{"tool_name":"Write"}' | STATE_STALE_DAYS=1 bash "$PT" 2>&1 >/dev/null)"
echo "$err" | grep -q "stale" \
  || fail "pretooluse: STATE_STALE_DAYS env override not respected (got: $err)"
rm -rf "$TMP"
ok "pretooluse: STATE_STALE_DAYS override works"

# Case 6: target tool, no PROJECT_STATE.md, exit code must be 0 (warn but not block)
TMP_EXIT="$(mktemp -d)"
( cd "$TMP_EXIT" && echo '{"tool_name":"Edit"}' | bash "$PT" 2>/dev/null )
rc=$?
rm -rf "$TMP_EXIT"
[[ "$rc" -eq 0 ]] || fail "pretooluse: must exit 0 even when warning (got rc=$rc)"
ok "pretooluse: exits 0 even when warning (never blocks)"

echo "test_orchestrator_hooks.sh: ALL PASS"
