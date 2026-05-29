#!/usr/bin/env bash
# tests/test_pipeline_hook.sh — unit tests for the UserPromptSubmit pipeline
# reminder hook (narrow keywords + once-per-session) and a sanity check on the
# language-overlay PostToolUse settings.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

PL="$ROOT/common/.claude/hooks/userpromptsubmit-pipeline.sh"
[[ -x "$PL" ]] || fail "pipeline hook is missing or not executable: $PL"

emitted() {  # emitted '<json payload>' -> prints additionalContext (empty if silent)
  printf '%s' "$1" | bash "$PL" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# --- Narrow keyword matching ---

# Feature-intent prompts → reminder fires.
for p in \
  '{"prompt":"로그인 기능 추가해줘"}' \
  '{"prompt":"새로운 기능 만들고 싶어"}' \
  '{"prompt":"implement a new payment flow"}' \
  '{"prompt":"add a new endpoint for users"}'; do
  out="$(emitted "$p")"
  echo "$out" | grep -q "PIPELINE PHASES" || fail "pipeline: expected reminder for: $p"
done
ok "pipeline: fires on narrow feature-intent keywords"

# Trivial / non-feature prompts → silent (the old broad pattern fired on these).
for p in \
  '{"prompt":"이 줄 추가해줘"}' \
  '{"prompt":"여기 변수 하나 만들어줘"}' \
  '{"prompt":"add a missing semicolon"}' \
  '{"prompt":"build the project and run tests"}' \
  '{"prompt":"이 버그 왜 났는지 봐줘"}'; do
  out="$(emitted "$p")"
  [[ -z "$out" ]] || fail "pipeline: should stay silent for trivial prompt: $p (got: $out)"
done
ok "pipeline: silent on trivial 'add/make/build' prompts (no false positives)"

# Empty / malformed payloads → silent, exit 0.
set +e
out="$(printf '{}' | bash "$PL" 2>/dev/null)"; rc=$?
set -e
[[ "$rc" -eq 0 && -z "$out" ]] || fail "pipeline: empty payload should be silent exit 0 (rc=$rc)"
set +e
out="$(printf 'not json' | bash "$PL" 2>/dev/null)"; rc=$?
set -e
[[ "$rc" -eq 0 && -z "$out" ]] || fail "pipeline: malformed payload should be silent exit 0 (rc=$rc)"
ok "pipeline: silent + exit 0 on empty/malformed payload"

# --- Once per session ---
SID="test-session-$$"
marker="${TMPDIR:-/tmp}/.pipeline-reminder.${SID}"
rm -f "$marker"
payload="$(printf '{"prompt":"새 기능 추가","session_id":"%s"}' "$SID")"
out1="$(emitted "$payload")"
echo "$out1" | grep -q "PIPELINE PHASES" || fail "pipeline: first call in session should fire"
out2="$(emitted "$payload")"
[[ -z "$out2" ]] || fail "pipeline: second call in same session should be silent (got: $out2)"
rm -f "$marker"
ok "pipeline: reminder injected at most once per session_id"

# --- jq-absent degradation ---
JQLESS_BIN="$(mktemp -d)"
for b in cat grep printf tr env bash dirname; do
  src="$(command -v "$b" 2>/dev/null)" && [[ -n "$src" ]] && ln -s "$src" "$JQLESS_BIN/$b" 2>/dev/null
done
set +e
out="$(printf '{"prompt":"새 기능 추가해줘"}' | PATH="$JQLESS_BIN" bash "$PL" 2>&1)"; rc=$?
set -e
[[ "$rc" -eq 0 && -z "$out" ]] || fail "pipeline: jq-absent should be silent exit 0 (rc=$rc out=$out)"
rm -rf "$JQLESS_BIN"
ok "pipeline: degrades to silent no-op when jq is absent"

# --- Language overlay PostToolUse settings sanity ---
for lang in go python rails; do
  s="$ROOT/langs/$lang/.claude/settings.json"
  jq empty "$s" || fail "lang settings invalid JSON: $s"
  cmd="$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$s")"
  echo "$cmd" | grep -q 'command -v jq' || fail "$lang PostToolUse hook missing jq guard"
done
ok "lang overlays: PostToolUse hooks are valid JSON and jq-guarded"

# Go must vet only the edited file's package, not the whole module (./...),
# to avoid dumping module-wide output into context on every edit.
go_cmd="$(jq -r '.hooks.PostToolUse[0].hooks[0].command' "$ROOT/langs/go/.claude/settings.json")"
echo "$go_cmd" | grep -q 'go vet \./\.\.\.' && fail "go hook still runs module-wide 'go vet ./...'"
echo "$go_cmd" | grep -q 'go vet \.' || fail "go hook should run package-scoped 'go vet .'"
ok "go overlay: vet is scoped to the edited file's package, not the whole module"

echo "test_pipeline_hook.sh: ALL PASS"
