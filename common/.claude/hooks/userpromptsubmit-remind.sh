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
# Conservative — false positives are worse than false negatives at Medium strength.
pattern='이전에|예전|전에 결정|왜 .{1,30}했|previously|earlier|why did we|revisit|past decision'

if echo "$prompt" | grep -iqE "$pattern"; then
  ctx="→ The user is referencing prior decisions. Read \`docs/decisions/README.md\` index first — decisions live in ADRs (immutable), not in git log. If you intend to change a locked decision, do it via /supersede, not by silently flipping it."
  jq -n --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
fi
