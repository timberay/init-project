# Orchestrator (PROJECT_STATE + ADR + Hooks) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-05-23-orchestrator-design.md`

**Goal:** Introduce a "single Orchestrator surface" (PROJECT_STATE.md + append-only ADRs + 3 hooks + 3 slash commands) into this template's `common/` so every bootstrapped project gets a soft-enforced mechanism for tracking current state and locked decisions. Apply it to this `init-project` repo itself.

**Architecture:** Plain Markdown files for state and decisions; bash hooks emit Claude Code's standard `{hookSpecificOutput:{hookEventName,additionalContext}}` JSON to inject context at SessionStart, UserPromptSubmit, and PreToolUse. Slash commands in `.claude/commands/` provide AI-drafted authoring with user approval.

**Tech Stack:** Bash 4+, `jq`, GNU/BSD `stat`, Markdown, Claude Code hook protocol, Claude Code slash command frontmatter.

---

## File Structure

### New files in `common/` (template — propagated to every bootstrapped project)

| Path | Purpose |
|---|---|
| `common/PROJECT_STATE.md` | Stub: 6 fixed sections with "Last Updated: never" |
| `common/docs/decisions/README.md` | ADR index — header + ADR-0000 row |
| `common/docs/decisions/ADR-0000-orchestrator-bootstrap.md` | Meta-ADR: this mechanism's own first decision |
| `common/.claude/hooks/sessionstart-inject-state.sh` | Injects STATE + ADR index at session start |
| `common/.claude/hooks/userpromptsubmit-remind.sh` | Reminds AI to check ADRs when user references prior decisions |
| `common/.claude/hooks/pretooluse-stale-check.sh` | Warns when PROJECT_STATE.md is >7 days stale before code edits |
| `common/.claude/commands/decide.md` | Slash command: draft a new ADR |
| `common/.claude/commands/state-sync.md` | Slash command: refresh PROJECT_STATE.md |
| `common/.claude/commands/supersede.md` | Slash command: supersede an existing ADR |

### Modified files in `common/`

| Path | Change |
|---|---|
| `common/.claude/settings.json` | Register 3 new hooks (SessionStart array + entries in PreToolUse, UserPromptSubmit) |
| `common/CLAUDE.md` | Add "Orchestrator (STATE + ADR)" section after Non-Negotiable Rules |
| `common/docs/standards/WORKFLOW.md` | Add per-phase orchestrator hooks table |

### Modified template machinery

| Path | Change |
|---|---|
| `lib/merge-settings.sh` | Add `SessionStart` to the list of arrays it concatenates (currently only handles PreToolUse/PostToolUse/UserPromptSubmit) |

### New tests

| Path | Purpose |
|---|---|
| `tests/test_orchestrator_hooks.sh` | Unit-test the 3 hook scripts: missing-file behavior, keyword detection, stale threshold |

### Modified tests

| Path | Change |
|---|---|
| `tests/test_merge_settings.sh` | Add case: SessionStart arrays merge correctly |
| `tests/smoke_empty.sh` | Assert new orchestrator files land in the bootstrapped project |
| `tests/smoke_rails.sh` | Same |
| `tests/smoke_python.sh` | Same |
| `tests/smoke_go.sh` | Same |
| `tests/run_all.sh` | Wire in `test_orchestrator_hooks.sh` |

### Self-application (init-project repo itself)

| Path | Change |
|---|---|
| `PROJECT_STATE.md` | New — populated to reflect actual current state |
| `docs/decisions/README.md` | New — index with ADR-0000 |
| `docs/decisions/ADR-0000-orchestrator-bootstrap.md` | New — same as common version |
| `.claude/settings.json` | New — registers the 3 hooks |
| `.claude/hooks/*.sh` | New — copy of common versions |
| `.claude/commands/*.md` | New — copy of common versions |

---

## Task 1: Extend `lib/merge-settings.sh` to merge `SessionStart` arrays

The current implementation only merges `PreToolUse`, `PostToolUse`, `UserPromptSubmit`. New hook event `SessionStart` will be added by this feature, so the merger must learn about it first — otherwise downstream language overlays could not contribute SessionStart entries.

**Files:**
- Modify: `lib/merge-settings.sh`
- Test: `tests/test_merge_settings.sh`

- [ ] **Step 1: Read the existing test to understand the pattern**

Run: `cat tests/test_merge_settings.sh`

Identify the existing assertion style. The test fixtures are inline heredocs.

- [ ] **Step 2: Write a failing test case for SessionStart merge**

Append to `tests/test_merge_settings.sh` (before the final pass line), a new test case:

```bash
# --- New: SessionStart arrays should concatenate ---
TMP_SS="$(mktemp -d)"
trap 'rm -rf "$TMP_SS"' EXIT

cat >"$TMP_SS/common.json" <<'EOF'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo common"}]}]}}
EOF
cat >"$TMP_SS/lang.json" <<'EOF'
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo lang"}]}]}}
EOF

source "$ROOT/lib/log.sh"
source "$ROOT/lib/merge-settings.sh"
merge_settings "$TMP_SS/common.json" "$TMP_SS/lang.json" "$TMP_SS/out.json" 0 \
  || fail "merge_settings failed for SessionStart"

count=$(jq '.hooks.SessionStart | length' "$TMP_SS/out.json")
[[ "$count" -eq 2 ]] || fail "SessionStart merge: expected 2 entries, got $count"
jq -e '.hooks.SessionStart[0].hooks[0].command == "echo common"' "$TMP_SS/out.json" >/dev/null \
  || fail "SessionStart merge: first entry not common"
jq -e '.hooks.SessionStart[1].hooks[0].command == "echo lang"' "$TMP_SS/out.json" >/dev/null \
  || fail "SessionStart merge: second entry not lang"
ok "merge_settings concatenates SessionStart"
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash tests/test_merge_settings.sh`
Expected: FAIL — `SessionStart merge: expected 2 entries, got 0` (or null), because the current merger drops SessionStart.

- [ ] **Step 4: Update `lib/merge-settings.sh` to include SessionStart**

Edit the `jq -s` invocation. Change:

```bash
  if ! jq -s '
    reduce .[] as $x (
      {hooks:{}};
      .hooks.PreToolUse       = ((.hooks.PreToolUse       // []) + ($x.hooks.PreToolUse       // [])) |
      .hooks.PostToolUse      = ((.hooks.PostToolUse      // []) + ($x.hooks.PostToolUse      // [])) |
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + ($x.hooks.UserPromptSubmit // []))
    )
  ' "$common" "$lang" > "$tmp"; then
```

to:

```bash
  if ! jq -s '
    reduce .[] as $x (
      {hooks:{}};
      .hooks.SessionStart     = ((.hooks.SessionStart     // []) + ($x.hooks.SessionStart     // [])) |
      .hooks.PreToolUse       = ((.hooks.PreToolUse       // []) + ($x.hooks.PreToolUse       // [])) |
      .hooks.PostToolUse      = ((.hooks.PostToolUse      // []) + ($x.hooks.PostToolUse      // [])) |
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + ($x.hooks.UserPromptSubmit // []))
    )
  ' "$common" "$lang" > "$tmp"; then
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test_merge_settings.sh`
Expected: PASS — including the new SessionStart case, and all existing cases still pass.

- [ ] **Step 6: Commit**

```bash
git add lib/merge-settings.sh tests/test_merge_settings.sh
git commit -m "feat(merge-settings): support SessionStart array concat

Required for the upcoming orchestrator hooks. Without this, common SessionStart
hooks would be dropped during settings deep-merge."
```

---

## Task 2: Create `sessionstart-inject-state.sh` hook

**Files:**
- Create: `common/.claude/hooks/sessionstart-inject-state.sh`
- Test: `tests/test_orchestrator_hooks.sh` (new file in this task)

- [ ] **Step 1: Create `tests/test_orchestrator_hooks.sh` with a failing test for sessionstart hook**

```bash
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
```

Make it executable:
```bash
chmod +x tests/test_orchestrator_hooks.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_orchestrator_hooks.sh`
Expected: FAIL — `common/.claude/hooks/sessionstart-inject-state.sh: No such file or directory`.

- [ ] **Step 3: Create the hook script**

Write `common/.claude/hooks/sessionstart-inject-state.sh`:

```bash
#!/usr/bin/env bash
# SessionStart hook: injects PROJECT_STATE.md and docs/decisions/README.md
# as additional context at the start of every Claude Code session.
#
# Output: Claude Code hook JSON
#   {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
#
# Runs from the project root (Claude Code's cwd when invoking hooks).

set -euo pipefail

state_file="PROJECT_STATE.md"
adr_index="docs/decisions/README.md"

ctx=""
if [[ -f "$state_file" ]]; then
  ctx+="=== PROJECT_STATE.md (orchestrator: current state) ==="$'\n'
  ctx+="$(cat "$state_file")"$'\n\n'
fi
if [[ -f "$adr_index" ]]; then
  ctx+="=== docs/decisions/README.md (ADR index — read before answering questions about prior decisions) ==="$'\n'
  ctx+="$(cat "$adr_index")"$'\n'
fi

if [[ -z "$ctx" ]]; then
  ctx="Orchestrator: PROJECT_STATE.md and docs/decisions/ are not initialized in this project. Run /state-sync to bootstrap once the first phase begins."
fi

jq -n --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
```

Make executable:
```bash
chmod +x common/.claude/hooks/sessionstart-inject-state.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_orchestrator_hooks.sh`
Expected: PASS for all three sessionstart cases.

- [ ] **Step 5: Commit**

```bash
git add common/.claude/hooks/sessionstart-inject-state.sh tests/test_orchestrator_hooks.sh
git commit -m "feat(orchestrator): add SessionStart hook to inject STATE + ADR index"
```

---

## Task 3: Create `userpromptsubmit-remind.sh` hook

**Files:**
- Create: `common/.claude/hooks/userpromptsubmit-remind.sh`
- Modify: `tests/test_orchestrator_hooks.sh`

- [ ] **Step 1: Append failing test cases**

Insert these blocks into `tests/test_orchestrator_hooks.sh` before the final `echo "test_orchestrator_hooks.sh: ALL PASS"`:

```bash
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

# Case 3: ordinary prompt → silent (no JSON output)
out="$(echo '{"prompt":"add a button to the login page"}' | bash "$UP")"
[[ -z "$out" ]] || fail "userpromptsubmit: should be silent on ordinary prompt, got: $out"
ok "userpromptsubmit: silent on non-matching prompt"

# Case 4: empty payload → silent
out="$(echo '{}' | bash "$UP")"
[[ -z "$out" ]] || fail "userpromptsubmit: should be silent on empty prompt, got: $out"
ok "userpromptsubmit: silent on empty payload"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_orchestrator_hooks.sh`
Expected: FAIL — `userpromptsubmit-remind.sh: No such file or directory`.

- [ ] **Step 3: Create the hook script**

Write `common/.claude/hooks/userpromptsubmit-remind.sh`:

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook: when the user references prior decisions, remind the
# AI to consult docs/decisions/ (the ADR index) before answering.
#
# Input (stdin, JSON): { "prompt": "<user message>", ... }
# Output (stdout, JSON, only when keywords match):
#   {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."}}

set -euo pipefail

payload="$(cat)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty')"

[[ -z "$prompt" ]] && exit 0

# Keywords that suggest the user is asking about prior decisions.
# Conservative list — false positives are worse than false negatives at Medium strength.
pattern='이전에|예전|전에 결정|왜 .{1,30}했|previously|earlier|why did we|revisit|past decision'

if echo "$prompt" | grep -iqE "$pattern"; then
  ctx="→ The user is referencing prior decisions. Read \`docs/decisions/README.md\` index first — decisions live in ADRs (immutable), not in git log. If you intend to change a locked decision, do it via /supersede, not by silently flipping it."
  jq -n --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
fi
```

Make executable:
```bash
chmod +x common/.claude/hooks/userpromptsubmit-remind.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_orchestrator_hooks.sh`
Expected: PASS for all sessionstart + userpromptsubmit cases.

- [ ] **Step 5: Commit**

```bash
git add common/.claude/hooks/userpromptsubmit-remind.sh tests/test_orchestrator_hooks.sh
git commit -m "feat(orchestrator): add UserPromptSubmit hook for ADR reminders"
```

---

## Task 4: Create `pretooluse-stale-check.sh` hook

**Files:**
- Create: `common/.claude/hooks/pretooluse-stale-check.sh`
- Modify: `tests/test_orchestrator_hooks.sh`

- [ ] **Step 1: Append failing test cases**

Insert before the final pass line:

```bash
# --- pretooluse-stale-check.sh ---

PT="$ROOT/common/.claude/hooks/pretooluse-stale-check.sh"

# Case 1: non-target tool → silent (matcher should also limit, but defensive in script too)
out="$(echo '{"tool_name":"Read"}' | bash "$PT")"
[[ -z "$out" ]] || fail "pretooluse: should be silent for Read, got: $out"
ok "pretooluse: silent for non-target tool"

# Case 2: target tool, no PROJECT_STATE.md → warning (stderr) but exit 0
TMP="$(mktemp -d)"
err="$(cd "$TMP" && echo '{"tool_name":"Edit"}' | bash "$PT" 2>&1 >/dev/null)"
echo "$err" | grep -q "missing" \
  || fail "pretooluse: missing-file warning not emitted (got: $err)"
rm -rf "$TMP"
ok "pretooluse: warns when PROJECT_STATE.md missing"

# Case 3: target tool, fresh PROJECT_STATE.md → no warning
TMP="$(mktemp -d)"
touch "$TMP/PROJECT_STATE.md"
out="$(cd "$TMP" && echo '{"tool_name":"Edit"}' | bash "$PT" 2>&1)"
[[ -z "$out" ]] || fail "pretooluse: should be silent on fresh STATE, got: $out"
rm -rf "$TMP"
ok "pretooluse: silent on fresh PROJECT_STATE.md"

# Case 4: target tool, stale PROJECT_STATE.md (>7 days) → warning
TMP="$(mktemp -d)"
touch "$TMP/PROJECT_STATE.md"
# Set mtime to 10 days ago. GNU touch -d "10 days ago"; BSD touch -t YYYYMMDDhhmm
if touch -d '10 days ago' "$TMP/PROJECT_STATE.md" 2>/dev/null; then
  :
else
  # BSD fallback
  ten_days_ago="$(date -v-10d +%Y%m%d%H%M 2>/dev/null || date -d '10 days ago' +%Y%m%d%H%M)"
  touch -t "$ten_days_ago" "$TMP/PROJECT_STATE.md"
fi
err="$(cd "$TMP" && echo '{"tool_name":"Edit"}' | bash "$PT" 2>&1 >/dev/null)"
echo "$err" | grep -qE 'stale|days' \
  || fail "pretooluse: stale warning not emitted (got: $err)"
rm -rf "$TMP"
ok "pretooluse: warns when PROJECT_STATE.md is >7 days stale"

# Case 5: STATE_STALE_DAYS=1 override → warns on 2-day-old file
TMP="$(mktemp -d)"
touch "$TMP/PROJECT_STATE.md"
if touch -d '2 days ago' "$TMP/PROJECT_STATE.md" 2>/dev/null; then
  :
else
  two_days_ago="$(date -v-2d +%Y%m%d%H%M 2>/dev/null || date -d '2 days ago' +%Y%m%d%H%M)"
  touch -t "$two_days_ago" "$TMP/PROJECT_STATE.md"
fi
err="$(cd "$TMP" && STATE_STALE_DAYS=1 echo '{"tool_name":"Write"}' | STATE_STALE_DAYS=1 bash "$PT" 2>&1 >/dev/null)"
echo "$err" | grep -q "stale" \
  || fail "pretooluse: STATE_STALE_DAYS env override not respected (got: $err)"
rm -rf "$TMP"
ok "pretooluse: STATE_STALE_DAYS override works"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_orchestrator_hooks.sh`
Expected: FAIL — `pretooluse-stale-check.sh: No such file or directory`.

- [ ] **Step 3: Create the hook script**

Write `common/.claude/hooks/pretooluse-stale-check.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse hook for Edit / Write / NotebookEdit: warn if PROJECT_STATE.md is
# missing or stale (>STATE_STALE_DAYS days old). Never blocks — warning only.
#
# Input (stdin, JSON): { "tool_name": "Edit|Write|NotebookEdit|...", ... }
# Output: warning on stderr (visible in transcript). Exit code always 0.

set -euo pipefail

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"

case "$tool" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

state_file="PROJECT_STATE.md"
threshold="${STATE_STALE_DAYS:-7}"

if [[ ! -f "$state_file" ]]; then
  printf '%s\n' "⚠ Orchestrator: PROJECT_STATE.md is missing. Run /state-sync to bootstrap." >&2
  exit 0
fi

# Cross-platform mtime in seconds since epoch (GNU coreutils + BSD/macOS).
mtime=$(stat -c %Y "$state_file" 2>/dev/null || stat -f %m "$state_file" 2>/dev/null || echo 0)
now=$(date +%s)
age_days=$(( (now - mtime) / 86400 ))

if (( age_days >= threshold )); then
  printf '%s\n' "⚠ Orchestrator: PROJECT_STATE.md is ${age_days} days stale (threshold: ${threshold}). Run /state-sync." >&2
fi

exit 0
```

Make executable:
```bash
chmod +x common/.claude/hooks/pretooluse-stale-check.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_orchestrator_hooks.sh`
Expected: PASS for all hook test cases.

- [ ] **Step 5: Commit**

```bash
git add common/.claude/hooks/pretooluse-stale-check.sh tests/test_orchestrator_hooks.sh
git commit -m "feat(orchestrator): add PreToolUse stale-check hook for PROJECT_STATE.md"
```

---

## Task 5: Register the 3 hooks in `common/.claude/settings.json`

**Files:**
- Modify: `common/.claude/settings.json`
- Test: `tests/test_merge_settings.sh` (already covers SessionStart from Task 1; this task just adds a smoke check that the file is valid JSON with our new entries)

- [ ] **Step 1: Write a one-shot validation test**

Create a temporary test fragment (do not commit) to verify after editing:

```bash
# Inline validation (not committed): run after editing the file
jq -e '.hooks.SessionStart | length >= 1' common/.claude/settings.json
jq -e '.hooks.PreToolUse | length >= 2' common/.claude/settings.json
jq -e '.hooks.UserPromptSubmit | length >= 2' common/.claude/settings.json
```

- [ ] **Step 2: Update `common/.claude/settings.json`**

Replace the entire file with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/sessionstart-inject-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Glob|Grep",
        "hooks": [
          {
            "type": "command",
            "command": "[ -f graphify-out/graph.json ] && echo '{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"graphify: Knowledge graph exists. Read graphify-out/GRAPH_REPORT.md for god nodes and community structure before searching raw files.\"}}' || true"
          }
        ]
      },
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pretooluse-stale-check.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "p=$(jq -r '.prompt'); if echo \"$p\" | grep -qiE '기능|구현|추가|만들|개발|feature|implement|build|develop'; then jq -n --rawfile ctx .claude/hooks/pipeline-reminder.txt '{hookSpecificOutput:{hookEventName:\"UserPromptSubmit\",additionalContext:$ctx}}'; fi",
            "timeout": 5,
            "statusMessage": "Checking pipeline phase..."
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/userpromptsubmit-remind.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Validate the JSON and entry counts**

Run:
```bash
jq empty common/.claude/settings.json && echo "valid JSON"
jq -e '.hooks.SessionStart | length >= 1' common/.claude/settings.json
jq -e '.hooks.PreToolUse | length >= 2' common/.claude/settings.json
jq -e '.hooks.UserPromptSubmit | length >= 2' common/.claude/settings.json
```
Expected: all four commands succeed (`valid JSON` printed; three `true` values).

- [ ] **Step 4: Re-run merge-settings test to confirm no regression**

Run: `bash tests/test_merge_settings.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add common/.claude/settings.json
git commit -m "feat(orchestrator): register STATE + ADR hooks in common settings.json"
```

---

## Task 6: Create `/decide` slash command

**Files:**
- Create: `common/.claude/commands/decide.md`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p common/.claude/commands
```

Write `common/.claude/commands/decide.md`:

```markdown
---
name: decide
description: Draft a new ADR from the current conversation. AI fills the template; user approves before save.
---

You are creating a new Architecture Decision Record (ADR).

## Steps

1. **Find the next ADR number.**
   Read `docs/decisions/README.md`. The next number is `max(existing) + 1`, or `0001` if only `0000-bootstrap` exists, or `0000` if the directory is empty. Format as 4 digits (`0007`).

2. **Identify the decision.**
   Look at the current conversation. State the decision in one sentence. If unclear, ask the user.

3. **Draft the ADR with all fields filled.**
   No placeholders. All fields below must have real content:

   ```markdown
   # ADR-NNNN: <Title — ≤80 chars, describing the decision>

   - **Status:** Proposed   <!-- or Accepted, if user says it's locked -->
   - **Date:** <today, YYYY-MM-DD>
   - **Supersedes:** (none)
   - **Superseded by:** (none)

   ## Context
   <2–4 sentences: what forces require this decision, what's at stake.>

   ## Decision
   <What was decided. 1–3 sentences, declarative.>

   ## Consequences
   - Positive: <one outcome>
   - Negative: <one tradeoff>
   - Neutral: <one observation, optional>
   ```

4. **Show the draft to the user.** Ask explicitly:
   > "ADR-NNNN draft above. Approve as-is, edit, or cancel?"

5. **On approval:**
   - Write the file to `docs/decisions/ADR-NNNN-<kebab-slug>.md`. The slug is a lowercase, dash-separated version of the title, ≤40 chars.
   - Add a row to the table in `docs/decisions/README.md`:
     `| NNNN | <Title> | <Status> | <Date> |`
   - If status is `Accepted`, also append one line to `PROJECT_STATE.md` "Locked Decisions" section:
     `- ADR-NNNN — <Title> (Accepted, <Date>)`

6. **Stage the new and modified files. Do not commit.**
   Run: `git add docs/decisions/ADR-NNNN-*.md docs/decisions/README.md PROJECT_STATE.md`
   Tell the user the files are staged and let them commit with their own message.

## Rules

- Never silently flip an existing `Accepted` ADR. If the user describes a decision that contradicts one, stop and tell them to use `/supersede ADR-XXXX` instead.
- If `docs/decisions/` doesn't exist, create it. The README is the table; nothing else.
- Slug examples: "Use SQLite for development, Postgres in production" → `sqlite-dev-postgres-prod`.
```

- [ ] **Step 2: Verify frontmatter parses**

Run: `head -5 common/.claude/commands/decide.md`
Expected: shows `---` / `name: decide` / `description: ...` / `---` block.

- [ ] **Step 3: Commit**

```bash
git add common/.claude/commands/decide.md
git commit -m "feat(orchestrator): add /decide slash command for ADR authoring"
```

---

## Task 7: Create `/state-sync` slash command

**Files:**
- Create: `common/.claude/commands/state-sync.md`

- [ ] **Step 1: Write the slash command file**

Write `common/.claude/commands/state-sync.md`:

```markdown
---
name: state-sync
description: Refresh PROJECT_STATE.md to reflect current session activity. AI proposes a diff; user approves before save.
---

You are syncing `PROJECT_STATE.md` — the project's "where are we right now" page.

## Steps

1. **Read the current state.**
   Read `PROJECT_STATE.md`. If it doesn't exist, create a stub with these six sections (all empty bodies except headers and a "Last Updated: never" line):

   ```markdown
   # PROJECT_STATE

   > Last Updated: never

   ## Current Phase
   (none)

   ## Locked Decisions
   See `docs/decisions/README.md`.

   ## Active Work
   (none)

   ## Open Questions
   (none)

   ## Out of Scope
   (none)

   ## Last Updated
   (see header)
   ```

2. **Survey current activity.** Gather facts:
   - `git log --oneline -10` for recent commits
   - `git status` for uncommitted changes
   - Files mentioned/edited in the current conversation
   - Active spec/plan files: `ls docs/superpowers/specs/ docs/superpowers/plans/` if they exist
   - Latest ADR (from `docs/decisions/README.md`)

3. **Propose updates to each section:**
   - **Current Phase:** Which of the 6 pipeline phases is active (see `docs/standards/WORKFLOW.md`). Include the active spec/plan paths if any.
   - **Locked Decisions:** Only update if a new ADR became `Accepted` since the last sync. Otherwise leave alone.
   - **Active Work:** In-progress items, one bullet each, ≤80 chars. If a previously active item shipped, remove it.
   - **Open Questions:** Pending decisions surfaced in the conversation that haven't been resolved.
   - **Out of Scope:** Items the user explicitly said no to.

4. **Show the proposed new PROJECT_STATE.md to the user.** Ask:
   > "Proposed PROJECT_STATE.md above. Approve, edit, or cancel?"

5. **On approval:**
   - Update the `Last Updated` header line:
     ```
     > Last Updated: <ISO 8601 timestamp, e.g. 2026-05-23T14:00:00+09:00> by <git config user.name> (session: <brief-tag>)
     ```
     The session tag is a short kebab-case label (e.g. `orchestrator-design`).
   - Write the file.

6. **Stage. Do not commit.**
   Run: `git add PROJECT_STATE.md`. Tell the user.

## Rules

- Hard cap: PROJECT_STATE.md must stay under 100 lines. If a section grows too long, that content belongs in an ADR or spec — link to it instead.
- Never write decision reasoning into PROJECT_STATE.md. Reasoning lives in ADRs.
- If `git config user.name` is empty, use `unknown`.
```

- [ ] **Step 2: Verify frontmatter parses**

Run: `head -5 common/.claude/commands/state-sync.md`
Expected: shows the frontmatter block.

- [ ] **Step 3: Commit**

```bash
git add common/.claude/commands/state-sync.md
git commit -m "feat(orchestrator): add /state-sync slash command for PROJECT_STATE refresh"
```

---

## Task 8: Create `/supersede` slash command

**Files:**
- Create: `common/.claude/commands/supersede.md`

- [ ] **Step 1: Write the slash command file**

Write `common/.claude/commands/supersede.md`:

```markdown
---
name: supersede
description: Create a new ADR that supersedes an existing one. The old ADR's status header is updated (only post-acceptance edit allowed).
---

You are creating a new ADR that supersedes an existing one.

**Usage:** `/supersede ADR-NNNN`

## Steps

1. **Parse the target.**
   The argument is `ADR-NNNN` (4-digit, padded). Locate the file: `docs/decisions/ADR-NNNN-*.md`. If not found, stop and tell the user.

2. **Verify status.**
   Read the file. Check the `Status:` line:
   - If `Proposed`: stop. Tell the user to edit it directly instead — `Proposed` is not locked yet.
   - If `Superseded by ADR-XXXX`: stop. Tell the user to supersede ADR-XXXX (the current head) instead.
   - If `Rejected`: stop. Tell the user this is historical and was never adopted.
   - If `Accepted`: proceed.

3. **Ask the user for the new decision.**
   > "What changed? State the new decision in one sentence, and why it replaces ADR-NNNN."

4. **Find the next ADR number.**
   Same logic as `/decide`: `max(existing) + 1`, 4-digit padded.

5. **Draft the new ADR.**
   Same template as `/decide`, but:
   - `Supersedes: ADR-NNNN` (filled in)
   - `Status: Accepted` (supersession is by definition an accepted action)
   - Add a `## Context` paragraph that explicitly references what ADR-NNNN said and why it no longer holds.

6. **Plan the edit to ADR-NNNN.**
   The ONLY change permitted is the `Status:` line:
   - From: `- **Status:** Accepted`
   - To:   `- **Status:** Superseded by ADR-MMMM`
   The body of ADR-NNNN must not change. (If the user wants to "correct" the old body, refuse — that is history rewriting.)

7. **Show both changes to the user:**
   - The new ADR-MMMM file contents
   - The single-line diff to ADR-NNNN's Status header
   Ask: "Approve both?"

8. **On approval:**
   - Write `docs/decisions/ADR-MMMM-<kebab-slug>.md`.
   - Edit ADR-NNNN: change only the Status header line.
   - Update `docs/decisions/README.md`:
     - Add a row for ADR-MMMM (Accepted)
     - Update ADR-NNNN's row: status → `Superseded by ADR-MMMM`
   - Append to `PROJECT_STATE.md` "Locked Decisions" section (since the new one is Accepted).

9. **Stage. Do not commit.**
   Run: `git add docs/decisions/ PROJECT_STATE.md`.

## Rules

- Never edit the body of an `Accepted` ADR. Only the status header may change, and only when superseding.
- The new ADR must explicitly reference what was superseded — both in the `Supersedes:` header AND in the `## Context` body.
- If the user can't articulate what changed since ADR-NNNN, push back: maybe the decision still holds and they just need a fresh read.
```

- [ ] **Step 2: Verify frontmatter parses**

Run: `head -5 common/.claude/commands/supersede.md`
Expected: shows the frontmatter block.

- [ ] **Step 3: Commit**

```bash
git add common/.claude/commands/supersede.md
git commit -m "feat(orchestrator): add /supersede slash command for ADR reversal"
```

---

## Task 9: Create `common/PROJECT_STATE.md`, `common/docs/decisions/README.md`, and `ADR-0000`

**Files:**
- Create: `common/PROJECT_STATE.md`
- Create: `common/docs/decisions/README.md`
- Create: `common/docs/decisions/ADR-0000-orchestrator-bootstrap.md`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p common/docs/decisions
```

- [ ] **Step 2: Write `common/PROJECT_STATE.md`** (template stub for downstream projects)

```markdown
# PROJECT_STATE

> Last Updated: never (run `/state-sync` to populate)

## Current Phase
(none yet)

## Locked Decisions
See `docs/decisions/README.md` for the index. Locked entries appear here as one-line pointers.

- ADR-0000 — Adopt PROJECT_STATE + ADR + Hooks orchestrator (Accepted)

## Active Work
(none yet)

## Open Questions
(none)

## Out of Scope
(none)

## Last Updated
(see header)
```

- [ ] **Step 3: Write `common/docs/decisions/README.md`**

```markdown
# Architecture Decision Records

Append-only log. Each ADR captures one decision: what was decided, why, and the consequences.

## Authoring

- `/decide` — draft a new ADR from conversation context
- `/supersede ADR-NNNN` — reverse a previously accepted ADR

## Rules

- Numbering is monotonic from `0000`. Never reused, never renumbered.
- `Accepted` ADRs are immutable. To reverse one, run `/supersede`.
- The only post-acceptance edit allowed is updating the `Status:` header to `Superseded by ADR-XXXX`.

## Index

| # | Title | Status | Date |
|---|-------|--------|------|
| 0000 | Adopt PROJECT_STATE + ADR + Hooks orchestrator | Accepted | 2026-05-23 |
```

- [ ] **Step 4: Write `common/docs/decisions/ADR-0000-orchestrator-bootstrap.md`**

```markdown
# ADR-0000: Adopt PROJECT_STATE + ADR + Hooks orchestrator

- **Status:** Accepted
- **Date:** 2026-05-23
- **Supersedes:** (none)
- **Superseded by:** (none)

## Context

AI-driven development in projects bootstrapped from this template exhibits three recurring failures:

1. Decision reversal — AI flips previously settled decisions because nothing tells it "this is locked."
2. History blindness — AI answers without reading prior decisions or design docs.
3. State misjudgment — AI reads a stale artifact and infers a current state that is no longer true.

The existing six-phase pipeline (`docs/standards/WORKFLOW.md`) addresses *process*, but Phase 1 and Phase 2 outputs live outside the repo (under `~/.gstack/`), so a fresh AI session cannot see them.

## Decision

Introduce a three-component "Orchestrator" surface that ships in `common/` and is propagated to every bootstrapped project:

1. **`PROJECT_STATE.md`** — a single page (≤100 lines, six fixed sections) that answers "where are we right now". Mutable, always current.
2. **`docs/decisions/`** — append-only ADR directory. Decisions are immutable; reversal requires a new ADR that supersedes the old one via the `Supersedes:` header.
3. **Three hooks + three slash commands** — `SessionStart` injects STATE and the ADR index; `UserPromptSubmit` reminds when the user references prior decisions; `PreToolUse` warns when STATE is stale. `/decide`, `/state-sync`, and `/supersede` are user-triggered, AI-drafted authoring flows.

Enforcement strength: **Medium**. Hooks inject context and warn; they do not block. Immutability of `Accepted` ADRs is enforced by convention (the slash commands won't edit the body), not by pre-commit hard checks.

## Consequences

- Positive: a fresh AI session sees STATE + ADR index before its first response. Decision history survives across sessions. Reversal requires an explicit supersede — silent drift is no longer possible without leaving an audit trail.
- Positive: zero dependency on `gstack`. Works in every bootstrapped project.
- Negative: small ritual overhead — phase transitions and major decisions require `/state-sync` and `/decide`.
- Neutral: this ADR system replaces nothing in the existing six-phase pipeline. It is a layer above it.
- Future: a follow-up ADR may upgrade immutability enforcement from convention to a pre-commit hard block.
```

- [ ] **Step 5: Verify the files are present**

```bash
ls -la common/PROJECT_STATE.md common/docs/decisions/
```
Expected: both files listed, plus `README.md` and `ADR-0000-orchestrator-bootstrap.md`.

- [ ] **Step 6: Commit**

```bash
git add common/PROJECT_STATE.md common/docs/decisions/
git commit -m "feat(orchestrator): add PROJECT_STATE stub, ADR index, and ADR-0000 bootstrap"
```

---

## Task 10: Add "Orchestrator" section to `common/CLAUDE.md`

**Files:**
- Modify: `common/CLAUDE.md`

- [ ] **Step 1: Read the current top of the file to find insertion point**

Run: `head -20 common/CLAUDE.md`

Insertion point: immediately after the `## Non-Negotiable Rules` block (ends before `## Standards Reference`).

- [ ] **Step 2: Insert the new section**

Find this anchor in `common/CLAUDE.md`:

```markdown
## Non-Negotiable Rules

- **Korean** for explanations and conversation; **English** for code, markdown,
  YAML, commit messages
- **TDD**: Red-Green-Refactor for every task. Write a failing test first.
- **Tidy First**: NEVER mix structural changes (refactoring) and behavioral
  changes (new logic) in a single commit
- **Small Commits**: Commit every time a test passes or a refactoring is done

## Standards Reference
```

Insert this new section between the bullet list and `## Standards Reference`:

```markdown

## Orchestrator (STATE + ADR)

Two files are required reading at the start of every session — the SessionStart
hook (`.claude/hooks/sessionstart-inject-state.sh`) already injects them, but
verify you have read them:

- **`PROJECT_STATE.md`** — "where the project is right now". Current phase,
  active spec/plan, locked decisions (as pointers), open questions, out-of-scope.
  Hard cap: 100 lines. **Mutable** — refresh with `/state-sync` at phase
  transitions and logical checkpoints.
- **`docs/decisions/README.md` + `ADR-NNNN-*.md`** — append-only decision log.
  `Accepted` ADRs are **immutable**. To reverse one, run `/supersede ADR-NNNN`
  — never edit the body of an Accepted ADR.

When the user references prior decisions ("이전에", "왜 X 했더라", "previously"),
consult `docs/decisions/` before answering. The UserPromptSubmit hook will
remind you. Decisions live in ADRs, not in git log.

When code edits trigger the PreToolUse stale warning (PROJECT_STATE.md older
than 7 days), run `/state-sync` to refresh before proceeding.

Slash commands:
- `/decide` — draft a new ADR from conversation context
- `/state-sync` — refresh PROJECT_STATE.md
- `/supersede ADR-NNNN` — reverse a previously accepted ADR

See `docs/decisions/ADR-0000-orchestrator-bootstrap.md` for the rationale.

```

- [ ] **Step 3: Verify the section landed correctly**

Run:
```bash
grep -A 1 "## Orchestrator" common/CLAUDE.md | head -3
```
Expected: shows the new heading and the line after it.

- [ ] **Step 4: Commit**

```bash
git add common/CLAUDE.md
git commit -m "docs(claude): add Orchestrator (STATE + ADR) section to common CLAUDE.md"
```

---

## Task 11: Add per-phase orchestrator hooks to `common/docs/standards/WORKFLOW.md`

**Files:**
- Modify: `common/docs/standards/WORKFLOW.md`

- [ ] **Step 1: Read current WORKFLOW.md structure**

Run: `grep -n "^##\|^###" common/docs/standards/WORKFLOW.md`

Identify where to add a new section. Append it at the end of the file, after the existing "Phase continuation rules" block.

- [ ] **Step 2: Append the new section**

Append to `common/docs/standards/WORKFLOW.md`:

```markdown

## Orchestrator hooks per phase

The Orchestrator mechanism (see `CLAUDE.md → Orchestrator (STATE + ADR)` and
`docs/decisions/ADR-0000-orchestrator-bootstrap.md`) integrates with the
six-phase pipeline at these points:

| Phase | Orchestrator action |
|---|---|
| 1 (Product) | On completion: `/decide` to capture WHAT/WHY as an ADR. The Phase 1 design doc itself stays under `~/.gstack/`, but the decision is preserved in-repo. |
| 2 (Architecture) | On completion: `/decide` for each major architectural choice (data flow, module boundaries, technology selection). |
| 3 (Technical Design) | Record the spec path in PROJECT_STATE.md "Current Phase / Active Spec" via `/state-sync` after writing the spec. |
| 4 (Task Breakdown) | Record the plan path in PROJECT_STATE.md "Current Phase / Active Plan" via `/state-sync`. |
| 5 (Execute) | `/state-sync` at logical checkpoints — not per task (too noisy), but when a substantial block of tasks lands. |
| 6 (Ship) | After merge: `/state-sync` to clear the shipped item from "Active Work". If the shipped work locked any new technical choices, run `/decide` to capture them. |

These are conventions, not blocking gates. Skip them only when the entire
pipeline is being skipped (bug fixes, refactors, tweaks).

```

- [ ] **Step 3: Verify**

Run:
```bash
grep -c "Orchestrator hooks per phase" common/docs/standards/WORKFLOW.md
```
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add common/docs/standards/WORKFLOW.md
git commit -m "docs(workflow): document per-phase orchestrator hooks"
```

---

## Task 12: Update smoke tests to assert orchestrator files land

**Files:**
- Modify: `tests/smoke_empty.sh`
- Modify: `tests/smoke_rails.sh`
- Modify: `tests/smoke_python.sh`
- Modify: `tests/smoke_go.sh`
- Modify: `tests/run_all.sh`

- [ ] **Step 1: Read current smoke_empty.sh to find insertion point**

Run: `cat tests/smoke_empty.sh`

The push2gh assertion (`[[ -f "$TMP/.claude/skills/push2gh/SKILL.md" ]]`) is the model. We add similar lines for the orchestrator files.

- [ ] **Step 2: Insert orchestrator assertions in `tests/smoke_empty.sh`**

After the existing `ok "push2gh skill bundled"` line, before `ok "--lang override works in empty dir"`, insert:

```bash
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
```

- [ ] **Step 3: Repeat the same block in `tests/smoke_rails.sh`, `smoke_python.sh`, `smoke_go.sh`**

Find a similar anchor (each has a `ok "push2gh ..."` line). Insert the same assertion block.

- [ ] **Step 4: Wire `test_orchestrator_hooks.sh` into `tests/run_all.sh`**

Read `tests/run_all.sh`:
```bash
cat tests/run_all.sh
```

It calls each unit test in sequence. Add `bash "$HERE/test_orchestrator_hooks.sh" || rc=1` (or matching style) alongside the others.

Concrete edit: find the line that runs `test_merge_settings.sh` and add immediately after:

```bash
bash "$HERE/test_orchestrator_hooks.sh" || rc=1
```

- [ ] **Step 5: Run all tests**

Run:
```bash
bash tests/run_all.sh
```
Expected: all tests PASS, including the new orchestrator hook tests and the four smoke tests with the new assertions.

- [ ] **Step 6: Commit**

```bash
git add tests/smoke_empty.sh tests/smoke_rails.sh tests/smoke_python.sh tests/smoke_go.sh tests/run_all.sh
git commit -m "test: assert orchestrator files land in bootstrapped projects"
```

---

## Task 13: Self-apply the orchestrator to this `init-project` repo

The mechanism is now in `common/`. This task copies it into the repo's root so init-project itself dogfoods the orchestrator. This makes ADR-0000 visible at repo root, gives this repo a real PROJECT_STATE, and means future sessions on init-project get the same SessionStart injection.

**Files:**
- Create: `PROJECT_STATE.md` (root)
- Create: `docs/decisions/README.md`
- Create: `docs/decisions/ADR-0000-orchestrator-bootstrap.md`
- Create: `.claude/settings.json`
- Create: `.claude/hooks/*.sh` (3 files)
- Create: `.claude/commands/*.md` (3 files)

- [ ] **Step 1: Copy the orchestrator pieces from `common/` to repo root**

```bash
cp common/PROJECT_STATE.md PROJECT_STATE.md
mkdir -p docs/decisions
cp common/docs/decisions/README.md docs/decisions/README.md
cp common/docs/decisions/ADR-0000-orchestrator-bootstrap.md docs/decisions/ADR-0000-orchestrator-bootstrap.md
mkdir -p .claude/hooks .claude/commands
cp common/.claude/hooks/sessionstart-inject-state.sh .claude/hooks/
cp common/.claude/hooks/userpromptsubmit-remind.sh .claude/hooks/
cp common/.claude/hooks/pretooluse-stale-check.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
cp common/.claude/commands/decide.md .claude/commands/
cp common/.claude/commands/state-sync.md .claude/commands/
cp common/.claude/commands/supersede.md .claude/commands/
```

- [ ] **Step 2: Create root `.claude/settings.json`**

This is **not** a copy of `common/.claude/settings.json` because init-project is not a downstream project — it has no language overlay, no graphify hook, no pipeline-reminder. Write just the orchestrator hooks:

```bash
cat > .claude/settings.json <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/sessionstart-inject-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pretooluse-stale-check.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/userpromptsubmit-remind.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
EOF
```

- [ ] **Step 3: Populate root `PROJECT_STATE.md` to reflect actual state**

Replace the stub with the real current state. Write to `PROJECT_STATE.md`:

```markdown
# PROJECT_STATE

> Last Updated: 2026-05-23 by tonny (session: orchestrator-bootstrap)

## Current Phase
- Phase: 6 — Ship (orchestrator feature)
- Active Spec: `docs/superpowers/specs/2026-05-23-orchestrator-design.md`
- Active Plan: `docs/superpowers/plans/2026-05-23-orchestrator.md`

## Locked Decisions
See `docs/decisions/README.md` for the full index.

- ADR-0000 — Adopt PROJECT_STATE + ADR + Hooks orchestrator (Accepted, 2026-05-23)

## Active Work
- [in-progress] Self-apply orchestrator to init-project (this PR)

## Open Questions
(none)

## Out of Scope
- Multi-team approval workflows
- Pre-commit hard blocks (Medium-strength enforcement only)
- Bringing Phase 1 / Phase 2 raw outputs in-repo (only decisions extracted to ADRs)

## Last Updated
(see header)
```

- [ ] **Step 4: Verify all files are present and JSON is valid**

```bash
jq empty .claude/settings.json && echo "valid JSON"
ls -la PROJECT_STATE.md docs/decisions/ .claude/hooks/ .claude/commands/
```
Expected: `valid JSON`, then listings showing all 11 new files (1 STATE + 2 ADR/index + 3 hooks + 3 commands + 1 settings + the docs/decisions/ directory itself).

- [ ] **Step 5: Smoke-test the SessionStart hook locally**

Run from the repo root:
```bash
bash .claude/hooks/sessionstart-inject-state.sh | jq .
```
Expected: JSON output with `hookSpecificOutput.additionalContext` containing the PROJECT_STATE.md content and the ADR index.

Run the stale check (should be silent — STATE.md is fresh):
```bash
echo '{"tool_name":"Edit"}' | bash .claude/hooks/pretooluse-stale-check.sh
```
Expected: no output, exit 0.

Run the reminder hook (should remind):
```bash
echo '{"prompt":"왜 이전에 X 했더라"}' | bash .claude/hooks/userpromptsubmit-remind.sh | jq .
```
Expected: JSON with reminder text.

- [ ] **Step 6: Final test pass**

Run: `bash tests/run_all.sh`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add PROJECT_STATE.md docs/decisions/ .claude/
git commit -m "feat(self): dogfood orchestrator in init-project repo

Adds PROJECT_STATE.md, docs/decisions/ADR-0000, and .claude/{hooks,commands,
settings.json} to the repo root so init-project itself uses the mechanism it
ships. ADR-0000 documents the meta-decision to adopt this system."
```

---

## Self-Review Notes

Coverage of spec acceptance criteria:

| AC | Task |
|---|---|
| 1. Fresh AI session sees STATE + ADR index before first response | Task 2 (SessionStart hook) + Task 13 step 5 (smoke test) |
| 2. "왜 X 했더라" triggers UserPromptSubmit reminder | Task 3 (UserPromptSubmit hook) + Task 13 step 5 |
| 3. Editing while STATE >7 days stale produces warning | Task 4 (PreToolUse hook) + Task 13 step 5 |
| 4. `/decide`, `/state-sync`, `/supersede` exist as slash commands | Tasks 6, 7, 8 |
| 5. ADR-0000 exists in this repo | Task 13 step 1 + Task 9 |
| 6. All smoke tests + new hook unit tests pass | Task 12 |

No placeholders. All hook scripts have full source. All slash command bodies are full prompts. All settings.json edits show the complete file. Smoke test inserts show the exact assertion block.

Type / name consistency check: hook script names match in settings.json registration (Task 5), in self-application (Task 13 step 2), and in smoke test assertions (Task 12). Slash command frontmatter names (`decide`, `state-sync`, `supersede`) match the filenames and the CLAUDE.md reference (Task 10).
