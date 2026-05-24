#!/usr/bin/env bash
# test_pre_commit_yamls.sh — every language overlay ships a parseable .pre-commit-config.yaml
# with the expected hygiene-hook block and at least one language-specific repo.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

for lang in python go rails; do
  f="$ROOT/langs/$lang/.pre-commit-config.yaml"
  [[ -f "$f" ]] || fail "$lang: .pre-commit-config.yaml missing"
  grep -q "^repos:" "$f" || fail "$lang: missing top-level 'repos:' key"
  grep -q "pre-commit/pre-commit-hooks" "$f" || fail "$lang: missing pre-commit/pre-commit-hooks block"
  grep -q "id: trailing-whitespace" "$f" || fail "$lang: missing trailing-whitespace hook"
  grep -q "id: end-of-file-fixer"   "$f" || fail "$lang: missing end-of-file-fixer hook"
  grep -q "id: check-yaml"          "$f" || fail "$lang: missing check-yaml hook"
  grep -q "id: detect-private-key"  "$f" || fail "$lang: missing detect-private-key hook"
  ok "$lang: .pre-commit-config.yaml shape OK"
done

# Per-language specific assertions
grep -q "astral-sh/ruff-pre-commit" "$ROOT/langs/python/.pre-commit-config.yaml" \
  || fail "python: missing ruff-pre-commit repo"
grep -q "id: go-fmt" "$ROOT/langs/go/.pre-commit-config.yaml" \
  || fail "go: missing go-fmt hook"
grep -q "rubocop" "$ROOT/langs/rails/.pre-commit-config.yaml" \
  || fail "rails: missing rubocop hook"

echo "test_pre_commit_yamls.sh: ALL PASS"
