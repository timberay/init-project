#!/usr/bin/env bash
# Test: detect_language returns rails/python/go/bash from the right manifest files,
# and respects the --lang override (passed as the function's positional arg).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=../lib/detect-language.sh
source "$ROOT/lib/detect-language.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Helper: run detect in a subshell that cd's into a fresh tmp dir.
detect_in() {
  local dir="$1" override="${2:-}"
  (cd "$dir" && detect_language "$override")
}

# Case 1: Gemfile → rails
mkdir "$TMP/rails-proj" && touch "$TMP/rails-proj/Gemfile"
r=$(detect_in "$TMP/rails-proj")
[[ "$r" == "rails" ]] || fail "Gemfile -> rails (got '$r')"
ok "Gemfile -> rails"

# Case 2: *.gemspec → rails
mkdir "$TMP/gem-proj" && touch "$TMP/gem-proj/foo.gemspec"
r=$(detect_in "$TMP/gem-proj")
[[ "$r" == "rails" ]] || fail "*.gemspec -> rails (got '$r')"
ok "*.gemspec -> rails"

# Case 3: pyproject.toml → python
mkdir "$TMP/py-proj" && touch "$TMP/py-proj/pyproject.toml"
r=$(detect_in "$TMP/py-proj")
[[ "$r" == "python" ]] || fail "pyproject.toml -> python (got '$r')"
ok "pyproject.toml -> python"

# Case 4: requirements.txt → python
mkdir "$TMP/req-proj" && touch "$TMP/req-proj/requirements.txt"
r=$(detect_in "$TMP/req-proj")
[[ "$r" == "python" ]] || fail "requirements.txt -> python (got '$r')"
ok "requirements.txt -> python"

# Case 5: Pipfile → python
mkdir "$TMP/pip-proj" && touch "$TMP/pip-proj/Pipfile"
r=$(detect_in "$TMP/pip-proj")
[[ "$r" == "python" ]] || fail "Pipfile -> python (got '$r')"
ok "Pipfile -> python"

# Case 6: go.mod → go
mkdir "$TMP/go-proj" && touch "$TMP/go-proj/go.mod"
r=$(detect_in "$TMP/go-proj")
[[ "$r" == "go" ]] || fail "go.mod -> go (got '$r')"
ok "go.mod -> go"

# Case 7: override beats detection
mkdir "$TMP/rails-but-py"
touch "$TMP/rails-but-py/Gemfile"
r=$(detect_in "$TMP/rails-but-py" "python")
[[ "$r" == "python" ]] || fail "--lang python override (got '$r')"
ok "override beats detection"

# Case 8: invalid override exits with code 2 specifically
set +e
( cd "$TMP/rails-proj" && detect_language "nodejs" ) >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || fail "invalid override should exit with code 2 (got $rc)"
ok "invalid override rejected with rc=2"

# Case 9: empty project defaults to bash
mkdir "$TMP/empty-proj"
r=$(detect_in "$TMP/empty-proj")
[[ "$r" == "bash" ]] || fail "empty project -> bash (got '$r')"
ok "empty project defaults to bash"

# Case 10: non-interactive empty project also defaults to bash
r=$( ( cd "$TMP/empty-proj" && BASE_FILES_NONINTERACTIVE=1 detect_language "" ) )
[[ "$r" == "bash" ]] || fail "non-interactive empty project -> bash (got '$r')"
ok "non-interactive empty project defaults to bash"

echo "test_detect_language.sh: ALL PASS"
