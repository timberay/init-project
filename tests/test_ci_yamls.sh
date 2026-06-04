#!/usr/bin/env bash
# test_ci_yamls.sh — every language overlay ships a parseable .github/workflows/ci.yml
# with the expected GitHub Actions structure: on triggers, runs-on, checkout, pre-commit, tests.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

for lang in python go rails bash nextjs; do
  f="$ROOT/langs/$lang/.github/workflows/ci.yml"
  [[ -f "$f" ]] || fail "$lang: ci.yml missing"
  grep -q "^name: CI"        "$f" || fail "$lang: ci.yml missing 'name: CI'"
  grep -q "^on:"              "$f" || fail "$lang: ci.yml missing 'on:' block"
  grep -q "pull_request:"     "$f" || fail "$lang: ci.yml missing pull_request trigger"
  grep -q "runs-on: ubuntu-latest" "$f" || fail "$lang: ci.yml not using ubuntu-latest"
  grep -q "actions/checkout"  "$f" || fail "$lang: ci.yml missing checkout step"
  grep -q "pre-commit run"    "$f" || fail "$lang: ci.yml missing 'pre-commit run' step"
  ok "$lang: ci.yml shape OK"
done

# Per-language specific assertions
grep -q "astral-sh/setup-uv" "$ROOT/langs/python/.github/workflows/ci.yml" \
  || fail "python: ci.yml missing setup-uv"
grep -q "pytest"             "$ROOT/langs/python/.github/workflows/ci.yml" \
  || fail "python: ci.yml missing pytest step"
grep -q "actions/setup-go"   "$ROOT/langs/go/.github/workflows/ci.yml" \
  || fail "go: ci.yml missing setup-go"
grep -q "go test"            "$ROOT/langs/go/.github/workflows/ci.yml" \
  || fail "go: ci.yml missing 'go test' step"
grep -q "ruby/setup-ruby"    "$ROOT/langs/rails/.github/workflows/ci.yml" \
  || fail "rails: ci.yml missing setup-ruby"
grep -q "bin/rails test"     "$ROOT/langs/rails/.github/workflows/ci.yml" \
  || fail "rails: ci.yml missing 'bin/rails test' step"
grep -q "shellcheck"         "$ROOT/langs/bash/.github/workflows/ci.yml" \
  || fail "bash: ci.yml missing shellcheck"
grep -q "bash -n"            "$ROOT/langs/bash/.github/workflows/ci.yml" \
  || fail "bash: ci.yml missing bash syntax check"
grep -q "actions/setup-node" "$ROOT/langs/nextjs/.github/workflows/ci.yml" \
  || fail "nextjs: ci.yml missing setup-node"
grep -q "npm run build --if-present" "$ROOT/langs/nextjs/.github/workflows/ci.yml" \
  || fail "nextjs: ci.yml missing build step"

echo "test_ci_yamls.sh: ALL PASS"
