#!/usr/bin/env bash
# Test: merge_settings deep-merges two settings.json files (array-concat for
# hooks.*) and validates the result.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=../lib/merge-settings.sh
source "$ROOT/lib/merge-settings.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/common.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Glob|Grep", "hooks": [ { "type": "command", "command": "echo common-pre" } ] }
    ],
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "echo common-ups" } ] }
    ]
  }
}
EOF

cat > "$TMP/lang.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo lang-pre" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [ { "type": "command", "command": "echo lang-post" } ] }
    ]
  }
}
EOF

# Case 1: produces merged JSON with both PreToolUse entries + PostToolUse + UserPromptSubmit
merge_settings "$TMP/common.json" "$TMP/lang.json" "$TMP/out.json" 0
jq empty "$TMP/out.json" || fail "merged JSON is invalid"

pre_count=$(jq '.hooks.PreToolUse | length' "$TMP/out.json")
[[ "$pre_count" -eq 2 ]] || fail "PreToolUse should have 2 entries (got $pre_count)"
post_count=$(jq '.hooks.PostToolUse | length' "$TMP/out.json")
[[ "$post_count" -eq 1 ]] || fail "PostToolUse should have 1 entry (got $post_count)"
ups_count=$(jq '.hooks.UserPromptSubmit | length' "$TMP/out.json")
[[ "$ups_count" -eq 1 ]] || fail "UserPromptSubmit should have 1 entry (got $ups_count)"
ok "deep merge concatenates arrays"

# Case 2: dry-run does not write output
rm -f "$TMP/out2.json"
merge_settings "$TMP/common.json" "$TMP/lang.json" "$TMP/out2.json" 1
[[ ! -f "$TMP/out2.json" ]] || fail "dry-run wrote a file"
ok "dry-run is read-only"

# Case 3: missing input file -> non-zero
set +e
merge_settings "$TMP/nope.json" "$TMP/lang.json" "$TMP/out3.json" 0 >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "missing input should fail (got rc=$rc)"
ok "missing input fails"

echo "test_merge_settings.sh: ALL PASS"
