#!/usr/bin/env bash
# smoke_nextjs.sh — package.json with next dependency present -> nextjs overlay applied.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/package.json" <<'JSON'
{
  "scripts": {
    "lint": "next lint",
    "typecheck": "tsc --noEmit",
    "build": "next build"
  },
  "dependencies": {
    "next": "latest",
    "react": "latest",
    "react-dom": "latest"
  },
  "devDependencies": {
    "typescript": "latest"
  }
}
JSON

out=$( cd "$TMP" && "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
echo "$out" | grep -q "language: nextjs" || fail "dry-run did not detect nextjs"
ok "dry-run detects nextjs"

( cd "$TMP" && "$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 ) || fail "real install exited non-zero"
grep -q "Next.js" "$TMP/docs/standards/STACK.md" || fail "STACK.md does not look like the Next.js overlay"
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("prettier") and contains("eslint")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference prettier and eslint"
[[ -f "$TMP/.pre-commit-config.yaml" ]] || fail ".pre-commit-config.yaml not installed"
grep -q "nextjs-lint" "$TMP/.pre-commit-config.yaml" || fail ".pre-commit-config.yaml missing nextjs-lint"
grep -q "nextjs-typecheck" "$TMP/.pre-commit-config.yaml" || fail ".pre-commit-config.yaml missing nextjs-typecheck"
[[ -f "$TMP/.github/workflows/ci.yml" ]] || fail "ci.yml not installed"
grep -q "actions/setup-node" "$TMP/.github/workflows/ci.yml" || fail "ci.yml missing setup-node"
[[ -f "$TMP/.gitignore" ]] || fail ".gitignore not installed"
grep -q "^node_modules/" "$TMP/.gitignore" || fail ".gitignore missing node_modules"
ok "real run installs nextjs overlay"

echo "smoke_nextjs.sh: ALL PASS"
