#!/usr/bin/env bash
# Test: install_skills calls 'claude plugin marketplace add' and
# 'claude plugin install' only for items not already present. Uses a fake
# `claude` binary on PATH that records every invocation.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=../lib/install-skills.sh
source "$ROOT/lib/install-skills.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CALLS="$TMP/claude_calls.log"

# Fake `claude`: records args; for `plugin marketplace list` and `plugin list`
# it emits lines controlled by env vars (CLAUDE_FAKE_MARKETPLACES /
# CLAUDE_FAKE_PLUGINS), so the test can simulate "already installed".
cat > "$TMP/bin/claude" <<'EOSH'
#!/usr/bin/env bash
echo "$*" >> "${CLAUDE_CALLS_LOG}"
if [[ "$1" == "plugin" && "$2" == "marketplace" && "$3" == "list" ]]; then
  printf '%s\n' ${CLAUDE_FAKE_MARKETPLACES:-}
  exit 0
fi
if [[ "$1" == "plugin" && "$2" == "list" ]]; then
  printf '%s\n' ${CLAUDE_FAKE_PLUGINS:-}
  exit 0
fi
exit 0
EOSH
mkdir -p "$TMP/bin"
mv "$TMP/bin/claude" "$TMP/bin/claude.tmp" 2>/dev/null || true
cat > "$TMP/bin/claude" <<'EOSH'
#!/usr/bin/env bash
echo "$*" >> "${CLAUDE_CALLS_LOG}"
if [[ "$1" == "plugin" && "$2" == "marketplace" && "$3" == "list" ]]; then
  printf '%s\n' ${CLAUDE_FAKE_MARKETPLACES:-}; exit 0
fi
if [[ "$1" == "plugin" && "$2" == "list" ]]; then
  printf '%s\n' ${CLAUDE_FAKE_PLUGINS:-}; exit 0
fi
exit 0
EOSH
chmod +x "$TMP/bin/claude"

export PATH="$TMP/bin:$PATH"
export CLAUDE_CALLS_LOG="$CALLS"

# Case 1: nothing installed -> 2 marketplaces added, 3 plugins installed
: > "$CALLS"
CLAUDE_FAKE_MARKETPLACES="" CLAUDE_FAKE_PLUGINS="" install_skills 0 >/dev/null 2>&1
grep -q "plugin marketplace add anthropics/claude-plugins-official"      "$CALLS" || fail "did not add claude-plugins-official"
grep -q "plugin marketplace add forrestchang/andrej-karpathy-skills"     "$CALLS" || fail "did not add karpathy-skills"
grep -q "plugin install superpowers@claude-plugins-official"             "$CALLS" || fail "did not install superpowers"
grep -q "plugin install code-review@claude-plugins-official"             "$CALLS" || fail "did not install code-review"
grep -q "plugin install andrej-karpathy-skills@karpathy-skills"          "$CALLS" || fail "did not install karpathy"
ok "fresh install adds all marketplaces + plugins"

# Case 2: everything already present -> no add/install
: > "$CALLS"
export CLAUDE_FAKE_MARKETPLACES="claude-plugins-official"$'\n'"karpathy-skills"
export CLAUDE_FAKE_PLUGINS="superpowers@claude-plugins-official"$'\n'"code-review@claude-plugins-official"$'\n'"andrej-karpathy-skills@karpathy-skills"
install_skills 0 >/dev/null 2>&1
grep -q "plugin marketplace add" "$CALLS" && fail "should not re-add marketplace"
grep -q "plugin install"          "$CALLS" && fail "should not re-install plugin"
ok "idempotent when already installed"

# Case 3: dry-run never invokes claude plugin install/add (but may invoke list)
: > "$CALLS"
unset CLAUDE_FAKE_MARKETPLACES CLAUDE_FAKE_PLUGINS
install_skills 1 >/dev/null 2>&1
grep -q "plugin marketplace add" "$CALLS" && fail "dry-run added marketplace"
grep -q "plugin install"          "$CALLS" && fail "dry-run installed plugin"
ok "dry-run is read-only"

echo "test_install_skills.sh: ALL PASS"
