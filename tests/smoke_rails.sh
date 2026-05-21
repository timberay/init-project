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
jq -e '.hooks.PreToolUse | length >= 2' "$TMP/.claude/settings.json" >/dev/null \
  || fail "merged settings.json should have at least 2 PreToolUse entries"
ok "real run installs rails overlay"

echo "smoke_rails.sh: ALL PASS"
