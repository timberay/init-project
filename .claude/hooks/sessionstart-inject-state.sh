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
