# Bootstrap Completeness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every project bootstrapped from this template work as a complete, conventional project — first `git commit` succeeds, quality gates run regardless of which tool initiated the commit, and standard dotfiles (`.editorconfig`, `.gitignore`, pre-commit, CI) are present.

**Architecture:** Migrate quality gating from Claude Code PreToolUse hooks to `pre-commit` (single source of truth) + GitHub Actions CI (re-runs pre-commit + tests). Add three universally-expected dotfiles per language overlay. Lock the ownership shift with ADR-0001. See spec at `docs/superpowers/specs/2026-05-24-bootstrap-completeness-design.md`.

**Tech Stack:** `pre-commit` (Python tool), GitHub Actions, bash test harness, jq for JSON assertions.

---

## File Structure

### New files
```
common/.editorconfig                                           [universal]
langs/python/.gitignore                                        [from github/gitignore/Python.gitignore]
langs/python/.pre-commit-config.yaml                           [hygiene + ruff]
langs/python/.github/workflows/ci.yml                          [uv → pre-commit → pytest]
langs/go/.gitignore                                            [from github/gitignore/Go.gitignore]
langs/go/.pre-commit-config.yaml                               [hygiene + gofmt + golangci-lint]
langs/go/.github/workflows/ci.yml                              [setup-go → pre-commit → go test]
langs/rails/.gitignore                                         [from github/gitignore/Rails.gitignore]
langs/rails/.pre-commit-config.yaml                            [hygiene + rubocop]
langs/rails/.github/workflows/ci.yml                           [setup-ruby → pre-commit → rails test]
docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md    [decision record]
tests/test_pre_commit_yamls.sh                                 [parse + structure check, 3 langs]
tests/test_ci_yamls.sh                                         [parse + structure check, 3 langs]
```

### Modified files
```
langs/python/.claude/settings.json                             [remove PreToolUse.Bash block]
langs/go/.claude/settings.json                                 [remove PreToolUse.Bash block]
langs/rails/.claude/settings.json                              [remove PreToolUse.Bash block]
docs/decisions/README.md                                       [add ADR-0001 index entry]
common/docs/standards/QUALITY.md                               [add gate-layering section, rewrite Pre-commit Failure Recovery]
lib/check-deps.sh                                              [warn if pre-commit missing]
install.sh                                                     [extend next-step hint]
README.md                                                      [update file-tree section]
PROJECT_STATE.md                                               [Active Spec + Plan paths via /state-sync, post-merge]
tests/smoke_python.sh                                          [assert new files exist + no Bash gate]
tests/smoke_go.sh                                              [same]
tests/smoke_rails.sh                                           [same]
```

### Unchanged (verified)
- `lib/copy-files.sh` — already walks dotfiles + hidden dirs via `find -type f -print0`.
- `common/.claude/hooks/*.sh` — orchestrator hooks are unrelated to quality gating.
- `common/.claude/settings.json` — orchestrator hooks unchanged; no Bash matcher there to begin with.

---

## Conventions for this plan

- **Run from project root:** `/home/tonny/projects/init-project`.
- **Commit style:** Conventional Commits (`feat`, `refactor`, `docs`, `chore`, `test`). See `RULES.md`.
- **Per-task test pattern:** write failing test → run-fail → implement → run-pass → commit. The "test" for pure documentation tasks is `grep -q '<expected string>' <file>`.
- **Smoke tests run with `RUN_SMOKE=1 tests/run_all.sh`** — they're slow (drive install.sh end-to-end) so they're opt-in. Unit-style `test_*.sh` always run.
- **Date used throughout:** 2026-05-24.

---

## Task 1: Add `common/.editorconfig`

**Files:**
- Create: `common/.editorconfig`
- Modify: `tests/smoke_python.sh`, `tests/smoke_go.sh`, `tests/smoke_rails.sh` (assertions)

- [ ] **Step 1: Add failing assertion to smoke tests**

Append to each of `tests/smoke_python.sh`, `tests/smoke_go.sh`, `tests/smoke_rails.sh` **before** the final `echo "smoke_*.sh: ALL PASS"` line:

```bash
[[ -f "$TMP/.editorconfig" ]] || fail ".editorconfig not installed"
grep -q "^root = true" "$TMP/.editorconfig" || fail ".editorconfig missing 'root = true'"
ok ".editorconfig bundled"
```

- [ ] **Step 2: Run smoke tests to verify they fail**

Run: `RUN_SMOKE=1 tests/smoke_python.sh`
Expected: FAIL with `.editorconfig not installed`. (Same for go and rails.)

- [ ] **Step 3: Create `common/.editorconfig`**

Write exactly this content:

```
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{py,go}]
indent_size = 4

[Makefile]
indent_style = tab

[*.md]
trim_trailing_whitespace = false
```

- [ ] **Step 4: Run smoke tests to verify they pass**

Run: `RUN_SMOKE=1 tests/smoke_python.sh && RUN_SMOKE=1 tests/smoke_go.sh && RUN_SMOKE=1 tests/smoke_rails.sh`
Expected: PASS for all three with `ok: .editorconfig bundled`.

- [ ] **Step 5: Commit**

```bash
git add common/.editorconfig tests/smoke_python.sh tests/smoke_go.sh tests/smoke_rails.sh
git commit -m "feat: add universal .editorconfig to bootstrap output"
```

---

## Task 2: Add `langs/python/.gitignore`

**Files:**
- Create: `langs/python/.gitignore`
- Modify: `tests/smoke_python.sh` (assertion)

- [ ] **Step 1: Add failing assertion to `tests/smoke_python.sh`**

Append before final `echo`:

```bash
[[ -f "$TMP/.gitignore" ]] || fail "Python .gitignore not installed"
grep -q "^__pycache__/" "$TMP/.gitignore" || fail "Python .gitignore missing __pycache__"
grep -q "^\.venv" "$TMP/.gitignore" || fail "Python .gitignore missing .venv"
ok "Python .gitignore bundled"
```

Note: the target dir already has a `.gitignore` (from `init-project`'s top-level `.gitignore`), so the assertion may currently spuriously pass on the file-existence check. To make the test strict, also assert it contains the Python-specific header:

```bash
head -3 "$TMP/.gitignore" | grep -q "github/gitignore" || fail ".gitignore is not the github/gitignore-sourced overlay"
```

Add this line as well.

- [ ] **Step 2: Run smoke test to verify it fails**

Run: `RUN_SMOKE=1 tests/smoke_python.sh`
Expected: FAIL on the `__pycache__` or `github/gitignore` assertion.

- [ ] **Step 3: Create `langs/python/.gitignore`**

Fetch the upstream file and prepend a 3-line header. Run:

```bash
mkdir -p langs/python
{
  echo "# Sourced verbatim from github/gitignore/Python.gitignore."
  echo "# Refresh with: curl -sL https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore"
  echo "# To customize, append project-specific entries below the upstream block."
  echo
  curl -fsSL https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore
} > langs/python/.gitignore
```

If `curl` is unavailable, use `wget -O - <url>` or copy the content manually from <https://github.com/github/gitignore/blob/main/Python.gitignore>.

- [ ] **Step 4: Run smoke test to verify it passes**

Run: `RUN_SMOKE=1 tests/smoke_python.sh`
Expected: PASS with `ok: Python .gitignore bundled`.

- [ ] **Step 5: Commit**

```bash
git add langs/python/.gitignore tests/smoke_python.sh
git commit -m "feat(python): add .gitignore from github/gitignore"
```

---

## Task 3: Add `langs/go/.gitignore`

**Files:**
- Create: `langs/go/.gitignore`
- Modify: `tests/smoke_go.sh` (assertion)

- [ ] **Step 1: Add failing assertion to `tests/smoke_go.sh`**

Append before final `echo`:

```bash
[[ -f "$TMP/.gitignore" ]] || fail "Go .gitignore not installed"
head -3 "$TMP/.gitignore" | grep -q "github/gitignore" || fail ".gitignore is not the github/gitignore-sourced overlay"
grep -qE "^\*\.exe" "$TMP/.gitignore" || fail "Go .gitignore missing *.exe"
ok "Go .gitignore bundled"
```

- [ ] **Step 2: Run smoke test to verify it fails**

Run: `RUN_SMOKE=1 tests/smoke_go.sh`
Expected: FAIL on header or content assertion.

- [ ] **Step 3: Create `langs/go/.gitignore`**

```bash
mkdir -p langs/go
{
  echo "# Sourced verbatim from github/gitignore/Go.gitignore."
  echo "# Refresh with: curl -sL https://raw.githubusercontent.com/github/gitignore/main/Go.gitignore"
  echo "# To customize, append project-specific entries below the upstream block."
  echo
  curl -fsSL https://raw.githubusercontent.com/github/gitignore/main/Go.gitignore
} > langs/go/.gitignore
```

- [ ] **Step 4: Run smoke test to verify it passes**

Run: `RUN_SMOKE=1 tests/smoke_go.sh`
Expected: PASS with `ok: Go .gitignore bundled`.

- [ ] **Step 5: Commit**

```bash
git add langs/go/.gitignore tests/smoke_go.sh
git commit -m "feat(go): add .gitignore from github/gitignore"
```

---

## Task 4: Add `langs/rails/.gitignore`

**Files:**
- Create: `langs/rails/.gitignore`
- Modify: `tests/smoke_rails.sh` (assertion)

- [ ] **Step 1: Add failing assertion to `tests/smoke_rails.sh`**

Append before final `echo`:

```bash
[[ -f "$TMP/.gitignore" ]] || fail "Rails .gitignore not installed"
head -3 "$TMP/.gitignore" | grep -q "github/gitignore" || fail ".gitignore is not the github/gitignore-sourced overlay"
grep -qE "^/log/\*" "$TMP/.gitignore" || fail "Rails .gitignore missing /log/*"
ok "Rails .gitignore bundled"
```

- [ ] **Step 2: Run smoke test to verify it fails**

Run: `RUN_SMOKE=1 tests/smoke_rails.sh`
Expected: FAIL on header or `/log/*` assertion.

- [ ] **Step 3: Create `langs/rails/.gitignore`**

```bash
mkdir -p langs/rails
{
  echo "# Sourced verbatim from github/gitignore/Rails.gitignore."
  echo "# Refresh with: curl -sL https://raw.githubusercontent.com/github/gitignore/main/Rails.gitignore"
  echo "# To customize, append project-specific entries below the upstream block."
  echo
  curl -fsSL https://raw.githubusercontent.com/github/gitignore/main/Rails.gitignore
} > langs/rails/.gitignore
```

- [ ] **Step 4: Run smoke test to verify it passes**

Run: `RUN_SMOKE=1 tests/smoke_rails.sh`
Expected: PASS with `ok: Rails .gitignore bundled`.

- [ ] **Step 5: Commit**

```bash
git add langs/rails/.gitignore tests/smoke_rails.sh
git commit -m "feat(rails): add .gitignore from github/gitignore"
```

---

## Task 5: Add `tests/test_pre_commit_yamls.sh` + `langs/python/.pre-commit-config.yaml`

**Files:**
- Create: `tests/test_pre_commit_yamls.sh`
- Create: `langs/python/.pre-commit-config.yaml`

- [ ] **Step 1: Write the failing unit test**

Create `tests/test_pre_commit_yamls.sh` with content:

```bash
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
```

Then make it executable: `chmod +x tests/test_pre_commit_yamls.sh`.

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/test_pre_commit_yamls.sh`
Expected: FAIL with `python: .pre-commit-config.yaml missing`.

- [ ] **Step 3: Create `langs/python/.pre-commit-config.yaml`**

Write exactly this content:

```yaml
# Single source of truth for fast quality checks at git commit time.
# Tests run in CI (see .github/workflows/ci.yml). Refresh hook versions with:
#   pre-commit autoupdate

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=1024']
      - id: mixed-line-ending
        args: ['--fix=lf']
      - id: detect-private-key
      - id: detect-aws-credentials
        args: ['--allow-missing-credentials']

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.0
    hooks:
      - id: ruff
        args: ['--fix']
      - id: ruff-format
```

- [ ] **Step 4: Run test — note Python check passes, Go/Rails still fail**

Run: `tests/test_pre_commit_yamls.sh`
Expected: FAIL with `go: .pre-commit-config.yaml missing` (Python check now passes, but the test iterates all three langs). This is expected.

- [ ] **Step 5: Commit (Python only — Go/Rails come in next tasks)**

```bash
git add tests/test_pre_commit_yamls.sh langs/python/.pre-commit-config.yaml
git commit -m "feat(python): add .pre-commit-config.yaml with hygiene + ruff hooks"
```

---

## Task 6: Add `langs/go/.pre-commit-config.yaml`

**Files:**
- Create: `langs/go/.pre-commit-config.yaml`

- [ ] **Step 1: Run unit test, confirm Go assertion still fails**

Run: `tests/test_pre_commit_yamls.sh`
Expected: FAIL with `go: .pre-commit-config.yaml missing` (the failing assertion from Task 5).

- [ ] **Step 2: Create `langs/go/.pre-commit-config.yaml`**

Write exactly this content:

```yaml
# Single source of truth for fast quality checks at git commit time.
# Tests run in CI (see .github/workflows/ci.yml). Refresh hook versions with:
#   pre-commit autoupdate

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=1024']
      - id: mixed-line-ending
        args: ['--fix=lf']
      - id: detect-private-key
      - id: detect-aws-credentials
        args: ['--allow-missing-credentials']

  - repo: https://github.com/dnephin/pre-commit-golang
    rev: v0.5.1
    hooks:
      - id: go-fmt
      - id: go-vet
      - id: go-mod-tidy

  - repo: local
    hooks:
      - id: golangci-lint
        name: golangci-lint
        entry: golangci-lint run
        language: system
        files: \.go$
        pass_filenames: false
```

- [ ] **Step 3: Run test — Python and Go pass, Rails still fails**

Run: `tests/test_pre_commit_yamls.sh`
Expected: FAIL with `rails: .pre-commit-config.yaml missing`.

- [ ] **Step 4: Commit**

```bash
git add langs/go/.pre-commit-config.yaml
git commit -m "feat(go): add .pre-commit-config.yaml with hygiene + gofmt + golangci-lint"
```

---

## Task 7: Add `langs/rails/.pre-commit-config.yaml`

**Files:**
- Create: `langs/rails/.pre-commit-config.yaml`

- [ ] **Step 1: Confirm Rails assertion fails**

Run: `tests/test_pre_commit_yamls.sh`
Expected: FAIL with `rails: .pre-commit-config.yaml missing`.

- [ ] **Step 2: Create `langs/rails/.pre-commit-config.yaml`**

Write exactly this content:

```yaml
# Single source of truth for fast quality checks at git commit time.
# Tests run in CI (see .github/workflows/ci.yml). Refresh hook versions with:
#   pre-commit autoupdate

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=1024']
      - id: mixed-line-ending
        args: ['--fix=lf']
      - id: detect-private-key
      - id: detect-aws-credentials
        args: ['--allow-missing-credentials']

  - repo: local
    hooks:
      - id: rubocop
        name: rubocop
        entry: bundle exec rubocop
        language: system
        files: \.rb$
```

- [ ] **Step 3: Run test — all three pass**

Run: `tests/test_pre_commit_yamls.sh`
Expected: PASS with `test_pre_commit_yamls.sh: ALL PASS`.

- [ ] **Step 4: Commit**

```bash
git add langs/rails/.pre-commit-config.yaml
git commit -m "feat(rails): add .pre-commit-config.yaml with hygiene + rubocop"
```

---

## Task 8: Add `tests/test_ci_yamls.sh` + `langs/python/.github/workflows/ci.yml`

**Files:**
- Create: `tests/test_ci_yamls.sh`
- Create: `langs/python/.github/workflows/ci.yml`

- [ ] **Step 1: Write the failing unit test**

Create `tests/test_ci_yamls.sh`:

```bash
#!/usr/bin/env bash
# test_ci_yamls.sh — every language overlay ships a parseable .github/workflows/ci.yml
# with the expected GitHub Actions structure: on triggers, runs-on, checkout, pre-commit, tests.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

for lang in python go rails; do
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

echo "test_ci_yamls.sh: ALL PASS"
```

Make executable: `chmod +x tests/test_ci_yamls.sh`.

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/test_ci_yamls.sh`
Expected: FAIL with `python: ci.yml missing`.

- [ ] **Step 3: Create `langs/python/.github/workflows/ci.yml`**

```bash
mkdir -p langs/python/.github/workflows
```

Write `langs/python/.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up uv
        uses: astral-sh/setup-uv@v3

      - name: Install dependencies
        run: uv sync --all-extras --dev

      - name: Install pre-commit
        run: uv tool install pre-commit

      - name: Run pre-commit
        run: uv run pre-commit run --all-files

      - name: Run tests
        run: uv run pytest -q
```

- [ ] **Step 4: Run test — Python passes, Go/Rails still fail**

Run: `tests/test_ci_yamls.sh`
Expected: FAIL with `go: ci.yml missing`.

- [ ] **Step 5: Commit**

```bash
git add tests/test_ci_yamls.sh langs/python/.github/workflows/ci.yml
git commit -m "feat(python): add CI workflow (pre-commit + pytest)"
```

---

## Task 9: Add `langs/go/.github/workflows/ci.yml`

**Files:**
- Create: `langs/go/.github/workflows/ci.yml`

- [ ] **Step 1: Confirm Go assertion fails**

Run: `tests/test_ci_yamls.sh`
Expected: FAIL with `go: ci.yml missing`.

- [ ] **Step 2: Create `langs/go/.github/workflows/ci.yml`**

```bash
mkdir -p langs/go/.github/workflows
```

Write content:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: stable

      - name: Download deps
        run: go mod download

      - name: Install pre-commit
        run: pipx install pre-commit

      - name: Install golangci-lint
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest
          args: --version

      - name: Run pre-commit
        run: pre-commit run --all-files

      - name: Run tests
        run: go test ./...
```

- [ ] **Step 3: Run test — Python and Go pass, Rails still fails**

Run: `tests/test_ci_yamls.sh`
Expected: FAIL with `rails: ci.yml missing`.

- [ ] **Step 4: Commit**

```bash
git add langs/go/.github/workflows/ci.yml
git commit -m "feat(go): add CI workflow (pre-commit + go test)"
```

---

## Task 10: Add `langs/rails/.github/workflows/ci.yml`

**Files:**
- Create: `langs/rails/.github/workflows/ci.yml`

- [ ] **Step 1: Confirm Rails assertion fails**

Run: `tests/test_ci_yamls.sh`
Expected: FAIL with `rails: ci.yml missing`.

- [ ] **Step 2: Create `langs/rails/.github/workflows/ci.yml`**

```bash
mkdir -p langs/rails/.github/workflows
```

Write content:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Install pre-commit
        run: pipx install pre-commit

      - name: Run pre-commit
        run: pre-commit run --all-files

      - name: Run tests
        run: bin/rails test
```

- [ ] **Step 3: Run test — all three pass**

Run: `tests/test_ci_yamls.sh`
Expected: PASS with `test_ci_yamls.sh: ALL PASS`.

- [ ] **Step 4: Commit**

```bash
git add langs/rails/.github/workflows/ci.yml
git commit -m "feat(rails): add CI workflow (pre-commit + rails test)"
```

---

## Task 11: Migrate `langs/python/.claude/settings.json` — remove `Bash(git commit*)` gates

**Files:**
- Modify: `langs/python/.claude/settings.json`
- Modify: `tests/smoke_python.sh` (negative assertion)

- [ ] **Step 1: Add failing negative assertion to `tests/smoke_python.sh`**

Append before final `echo`:

```bash
# ADR-0001: Bash(git commit*) gates moved to pre-commit/CI; no Bash matcher should remain
! jq -e '.hooks.PreToolUse[] | select(.matcher | tostring | contains("Bash"))' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PreToolUse should not have a Bash matcher (ADR-0001: gating moved to pre-commit/CI)"
ok "ADR-0001: no PreToolUse Bash gate present"
```

- [ ] **Step 2: Run smoke test to verify it fails**

Run: `RUN_SMOKE=1 tests/smoke_python.sh`
Expected: FAIL with `PreToolUse should not have a Bash matcher`.

- [ ] **Step 3: Edit `langs/python/.claude/settings.json` — delete the PreToolUse Bash block**

Open `langs/python/.claude/settings.json`. Remove the entire `PreToolUse` array (lines 3–23 in the current file — the block containing matcher `"Bash"` with the pytest and ruff `Bash(git commit*)` hooks). The `PostToolUse` block must remain unchanged.

The file after edit should look exactly like this:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | { read -r f; if [[ \"$f\" == *.py ]] && command -v ruff >/dev/null; then ruff format \"$f\" >/dev/null 2>&1; ruff check \"$f\" 2>&1; fi; } 2>/dev/null || true",
            "timeout": 30,
            "statusMessage": "Formatting and linting Python file..."
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Run smoke test to verify it passes**

Run: `RUN_SMOKE=1 tests/smoke_python.sh`
Expected: PASS with `ok: ADR-0001: no PreToolUse Bash gate present`.

- [ ] **Step 5: Commit**

```bash
git add langs/python/.claude/settings.json tests/smoke_python.sh
git commit -m "feat(python)!: migrate quality gates to pre-commit/CI (ADR-0001)

BREAKING CHANGE: Removes the PreToolUse Bash(git commit*) deny gates
that ran pytest and ruff before commit. Replaced by .pre-commit-config.yaml
(ruff) + .github/workflows/ci.yml (pre-commit + pytest). Empty-project
first commit now succeeds without intervention.

Refs ADR-0001."
```

---

## Task 12: Migrate `langs/go/.claude/settings.json`

**Files:**
- Modify: `langs/go/.claude/settings.json`
- Modify: `tests/smoke_go.sh` (negative assertion)

- [ ] **Step 1: Add failing negative assertion to `tests/smoke_go.sh`**

Append before final `echo`:

```bash
! jq -e '.hooks.PreToolUse[] | select(.matcher | tostring | contains("Bash"))' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PreToolUse should not have a Bash matcher (ADR-0001: gating moved to pre-commit/CI)"
ok "ADR-0001: no PreToolUse Bash gate present"
```

- [ ] **Step 2: Run smoke test to verify it fails**

Run: `RUN_SMOKE=1 tests/smoke_go.sh`
Expected: FAIL with `PreToolUse should not have a Bash matcher`.

- [ ] **Step 3: Edit `langs/go/.claude/settings.json` — delete the PreToolUse Bash block**

Remove the `PreToolUse` array. The file after edit should be:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | { read -r f; if [[ \"$f\" == *.go ]] && command -v gofmt >/dev/null; then gofmt -w \"$f\" >/dev/null 2>&1; go vet ./... 2>&1; fi; } 2>/dev/null || true",
            "timeout": 30,
            "statusMessage": "Formatting and vetting Go file..."
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Run smoke test to verify it passes**

Run: `RUN_SMOKE=1 tests/smoke_go.sh`
Expected: PASS with `ok: ADR-0001: no PreToolUse Bash gate present`.

- [ ] **Step 5: Commit**

```bash
git add langs/go/.claude/settings.json tests/smoke_go.sh
git commit -m "feat(go)!: migrate quality gates to pre-commit/CI (ADR-0001)

BREAKING CHANGE: Removes the PreToolUse Bash(git commit*) deny gates
that ran 'go test' and golangci-lint before commit. Replaced by
.pre-commit-config.yaml (gofmt/govet/tidy + golangci-lint) +
.github/workflows/ci.yml (pre-commit + go test).

Refs ADR-0001."
```

---

## Task 13: Migrate `langs/rails/.claude/settings.json`

**Files:**
- Modify: `langs/rails/.claude/settings.json`
- Modify: `tests/smoke_rails.sh` (negative assertion)

- [ ] **Step 1: Update existing assertion in `tests/smoke_rails.sh`**

The current `smoke_rails.sh:26-27` asserts `PreToolUse | length >= 2` — this depends on the Bash matcher. After migration, the only PreToolUse entries come from `common/` (the graphify Glob|Grep one and the pretooluse-stale-check Edit|Write|NotebookEdit one). Change line 26–27 from `>= 2` to `>= 1` (since the migrated overlay no longer contributes PreToolUse entries, only common does):

```bash
jq -e '.hooks.PreToolUse | length >= 1' "$TMP/.claude/settings.json" >/dev/null \
  || fail "merged settings.json should have at least 1 PreToolUse entry (orchestrator stale-check)"
```

Then append the negative assertion:

```bash
! jq -e '.hooks.PreToolUse[] | select(.matcher | tostring | contains("Bash"))' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PreToolUse should not have a Bash matcher (ADR-0001: gating moved to pre-commit/CI)"
ok "ADR-0001: no PreToolUse Bash gate present"
```

- [ ] **Step 2: Run smoke test to verify it fails**

Run: `RUN_SMOKE=1 tests/smoke_rails.sh`
Expected: FAIL with `PreToolUse should not have a Bash matcher`.

- [ ] **Step 3: Edit `langs/rails/.claude/settings.json` — delete the PreToolUse Bash block**

The file after edit should be:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "export PATH=\"$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH\"; jq -r '.tool_input.file_path' | { read -r f; if [[ \"$f\" == *.rb ]] && [ -x bin/rubocop ]; then bin/rubocop \"$f\" 2>&1; fi; } 2>/dev/null || true",
            "timeout": 30,
            "statusMessage": "Linting Ruby file..."
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Run smoke test to verify it passes**

Run: `RUN_SMOKE=1 tests/smoke_rails.sh`
Expected: PASS with `ok: ADR-0001: no PreToolUse Bash gate present`.

- [ ] **Step 5: Commit**

```bash
git add langs/rails/.claude/settings.json tests/smoke_rails.sh
git commit -m "feat(rails)!: migrate quality gates to pre-commit/CI (ADR-0001)

BREAKING CHANGE: Removes the PreToolUse Bash(git commit*) deny gates
that ran 'bin/rails test' and rubocop before commit. Replaced by
.pre-commit-config.yaml (rubocop) + .github/workflows/ci.yml
(pre-commit + bin/rails test).

Refs ADR-0001."
```

---

## Task 14: Add ADR-0001 + update ADR index

**Files:**
- Create: `docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md`
- Modify: `docs/decisions/README.md`

- [ ] **Step 1: Write failing assertion**

Create or update a test command (used inline, not a permanent test file):

```bash
test -f docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md && \
  grep -q "ADR-0001" docs/decisions/README.md
```

Run: `test -f docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md && grep -q "ADR-0001" docs/decisions/README.md && echo PASS || echo FAIL`
Expected: FAIL.

- [ ] **Step 2: Create the ADR**

Write `docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md`:

```markdown
# ADR-0001: Quality gates owned by pre-commit + CI; Claude hooks are advisory

- **Status:** Accepted
- **Date:** 2026-05-24
- **Supersedes:** (none — extends ADR-0000)
- **Superseded by:** (none)

## Context

The pre-existing template enforced quality (pytest, ruff, go test, golangci-lint, bin/rails test, rubocop) exclusively through Claude Code `.claude/settings.json` PreToolUse hooks that intercepted `Bash(git commit*)`. Two structural defects followed from this design:

1. **Tool lock-in.** Any `git commit` initiated outside Claude Code (terminal, IDE source-control UI, GitHub web editor, CI) bypassed enforcement entirely. The template promised quality only inside one specific tool.
2. **Empty-project first-commit failure.** The Python overlay's `pytest -q` gate exited 5 ("no tests collected") on a freshly-bootstrapped project, denying the very first commit that `install.sh` suggested. Go (`go test ./...`) and Rails (`bin/rails test`) had the same structural risk.

## Decision

`.pre-commit-config.yaml` (per language overlay) is the single source of truth for fast quality checks at commit time. `.github/workflows/ci.yml` (per language overlay) re-runs `pre-commit run --all-files` and additionally runs the test suite. Claude Code language-specific `.claude/settings.json` PreToolUse hooks that gated `Bash(git commit*)` are removed. PostToolUse format-on-save hooks are retained as edit-time feedback.

Tests are confined to CI; pre-commit is restricted to fast checks (linter, formatter, hygiene). Empty-project first commit succeeds because no test runner sits between the user and the commit at the local layer.

## Consequences

- Positive: gates run regardless of the tool that initiated the commit (terminal, IDE, CI).
- Positive: single source of truth for check definitions; same yaml reused in local pre-commit hook and in CI.
- Positive: empty-project bootstrap commit succeeds without intervention.
- Positive: matches mainstream language-ecosystem conventions (cookiecutter, copier, `rails new`).
- Negative: requires `pre-commit` binary installed (Python tool — `pipx install pre-commit` or `uv tool install pre-commit`). Documented in `common/docs/standards/QUALITY.md` and `install.sh` next-step hint.
- Neutral: Claude Code retains `PostToolUse` format-on-save hooks for immediate edit feedback. The orchestrator hooks (`SessionStart`/`UserPromptSubmit`/`PreToolUse` stale-check) are unrelated and unchanged.

This ADR extends ADR-0000's "Medium-strength enforcement" philosophy to the quality-gate layer: hooks across all surfaces inject context and warn or fail loudly, but the canonical gating mechanism is conventional git+CI tooling, not Claude Code's PreToolUse system.
```

- [ ] **Step 3: Update `docs/decisions/README.md` index**

Edit `docs/decisions/README.md`. In the `## Index` table, append a new row after the ADR-0000 row:

```markdown
| 0001 | Quality gates owned by pre-commit + CI | Accepted | 2026-05-24 |
```

- [ ] **Step 4: Verify**

Run: `test -f docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md && grep -q "ADR-0001" docs/decisions/README.md && echo PASS || echo FAIL`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md docs/decisions/README.md
git commit -m "docs(adr): add ADR-0001 — quality gates owned by pre-commit + CI"
```

---

## Task 15: Update `common/docs/standards/QUALITY.md`

**Files:**
- Modify: `common/docs/standards/QUALITY.md`

- [ ] **Step 1: Test setup — assert the new section heading does NOT yet exist**

Run: `grep -q "^## Quality Gate Layering" common/docs/standards/QUALITY.md && echo PASS || echo FAIL`
Expected: FAIL.

- [ ] **Step 2: Rewrite the "Pre-commit Failure Recovery" section and insert the new gate-layering section**

Open `common/docs/standards/QUALITY.md`. Find the section starting at line 133 (`## Pre-commit Failure Recovery`). Replace the entire section (lines 133–147) with:

```markdown
## Quality Gate Layering

This project enforces quality at four distinct layers. Each layer answers a different question and has a different owner.

| Layer | When | Owner | Strength |
|---|---|---|---|
| Edit-time format/lint | On file save inside Claude Code | `.claude/settings.json` PostToolUse | Auto-fix, no block |
| Commit-time fast checks | On `git commit` (any tool) | `.pre-commit-config.yaml` (run via the installed git hook) | Block on violation |
| CI fast + slow checks | On PR / push to `main` | `.github/workflows/ci.yml` | Block merge |
| Orchestrator hooks (unrelated) | Session start, prompt submit, stale state | `.claude/hooks/*.sh` | Soft inject / warn |

The single source of truth for fast checks is `.pre-commit-config.yaml`. CI re-runs `pre-commit run --all-files` and adds the test suite. Locally, `pre-commit install` (one-time, after `git init`) registers the git hook so every `git commit` runs the same yaml.

This layered design is locked by ADR-0001. See `docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md` for the rationale.

## Pre-commit Failure Recovery

The recovery workflow is universal across layers:

- **Linter/formatter violations**: run the auto-fix command (`ruff check --fix`, `gofmt -w`, `bin/rubocop -a`), manually resolve the rest, re-stage, retry the commit.
- **Test failure (CI)**: diagnose the failing test locally, fix the code, verify with the local test command, push.
- **Multiple issues**: fix lint first (cheap, often auto-fixable), then tests, then retry.
- **Never** bypass with `git commit --no-verify`. If a hook is wrong, fix the hook in a separate commit.
- **First-time setup on a fresh clone**: `pre-commit install` registers the git hook. Without this, the local commit-time gate does not run (CI still does).

For the code-review checklist that gates merging, see `REVIEW.md`. For the exact linter and test commands, see the language overlay's `TOOLS.md`.
```

- [ ] **Step 3: Verify**

Run: `grep -q "^## Quality Gate Layering" common/docs/standards/QUALITY.md && grep -q "ADR-0001" common/docs/standards/QUALITY.md && echo PASS || echo FAIL`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add common/docs/standards/QUALITY.md
git commit -m "docs(quality): document four-layer quality gate model (ADR-0001)"
```

---

## Task 16: Add `pre-commit` to `lib/check-deps.sh` + extend `install.sh` next-step hint

**Files:**
- Modify: `lib/check-deps.sh`
- Modify: `install.sh`
- Modify: `tests/test_check_deps.sh` (if it asserts the missing-list contents)

- [ ] **Step 1: Inspect existing dep-check test**

Run: `cat tests/test_check_deps.sh` to understand its assertion shape. (Read-only inspection step.)

- [ ] **Step 2: Add `pre-commit` to `REQUIRED_OS` and an install hint**

Edit `lib/check-deps.sh:7-9`. Change:

```bash
if [[ -z "${REQUIRED_OS:-}" ]]; then
  REQUIRED_OS=(jq git)
fi
```

to:

```bash
if [[ -z "${REQUIRED_OS:-}" ]]; then
  REQUIRED_OS=(jq git pre-commit)
fi
```

Edit `lib/check-deps.sh:15-26`. In the `_install_hint()` function, add a new case for `pre-commit` before the catch-all `*)`:

```bash
    pre-commit) echo "pipx install pre-commit          # or: uv tool install pre-commit" ;;
```

- [ ] **Step 3: Extend `install.sh` next-step hint**

Edit `install.sh:104`. Change:

```bash
log_info "next: git init && git add . && git commit -m 'Bootstrap from base-files'"
```

to:

```bash
log_info "next: git init && git add . && git commit -m 'Bootstrap from base-files'"
log_info "      then: pre-commit install   # registers the git hook (one-time)"
```

- [ ] **Step 4: Run dep-check test and any smoke tests to confirm green**

Run: `tests/test_check_deps.sh && RUN_SMOKE=1 tests/smoke_python.sh`
Expected: PASS for both. If `test_check_deps.sh` hard-codes `MISSING_DEPS=(jq git)`, update its expectation to include `pre-commit` only when pre-commit is genuinely missing on the test runner.

If the test asserts based on what `command -v` returns, no change needed.

- [ ] **Step 5: Commit**

```bash
git add lib/check-deps.sh install.sh tests/test_check_deps.sh
git commit -m "feat(install): require pre-commit; extend next-step hint"
```

(Drop `tests/test_check_deps.sh` from the `git add` list if no change was needed.)

---

## Task 17: Update `README.md` file-tree section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Locate the layout section**

Run: `grep -n "PROJECT_STATE.md\|push2gh\|pipeline-reminder" README.md | head -10`

This identifies the file-tree block (around line 50–60 based on prior grep).

- [ ] **Step 2: Inspect current layout block**

Read `README.md` and find the tree-style listing of files the installer produces. Identify the insertion points for `.editorconfig`, `.gitignore`, `.pre-commit-config.yaml`, `.github/workflows/ci.yml`.

- [ ] **Step 3: Update the tree**

Insert (or extend the existing tree to include) the new artifacts. Example block to add — actual placement depends on current README structure:

```
.editorconfig                          # Universal editor config (whitespace, EOL)
.gitignore                             # Language-specific (from github/gitignore)
.pre-commit-config.yaml                # Commit-time fast checks (ADR-0001)
.github/
└── workflows/
    └── ci.yml                         # CI: pre-commit + tests on PR + push to main
```

- [ ] **Step 4: Verify**

Run: `grep -q ".pre-commit-config.yaml" README.md && grep -q "ci.yml" README.md && echo PASS || echo FAIL`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(readme): list new bootstrap artifacts in file tree"
```

---

## Task 18: Update `PROJECT_STATE.md` via `/state-sync` (post-merge)

**Note:** This is **not** a code task in the usual sense — it is a user-triggered orchestrator action per WORKFLOW.md Phase 5 conventions. After all preceding tasks land and the PR merges:

- [ ] **Step 1: User runs `/state-sync` slash command**

In a Claude Code session at project root, type `/state-sync`. The slash command will propose a diff to `PROJECT_STATE.md` updating:

- `Active Spec`: from `2026-05-23-orchestrator-design.md` → cleared (work shipped)
- `Active Plan`: from `2026-05-23-orchestrator.md` → cleared
- `Active Work`: remove the in-progress item; add a completed marker for "bootstrap completeness (ADR-0001)" if desired
- `Locked Decisions`: add `ADR-0001 — Quality gates owned by pre-commit + CI (Accepted, 2026-05-24)`
- `Last Updated`: bump to current timestamp

User reviews and approves the diff. The slash command writes the updated file and commits it.

- [ ] **Step 2: Commit (by /state-sync)**

The `/state-sync` command produces a commit of the form:

```
chore(state): sync PROJECT_STATE.md after ADR-0001 ship
```

---

## Final Verification

After all 18 tasks complete, run the full test matrix:

```bash
tests/run_all.sh              # unit-style test_*.sh — must pass
RUN_SMOKE=1 tests/run_all.sh  # also runs smoke_*.sh — must pass
```

Expected output:

```
passed: 12+ tests (depending on smoke flag)
failed: 0
```

Then verify the contract on a real bootstrap into a tempdir:

```bash
TMP=$(mktemp -d)
touch "$TMP/pyproject.toml"
( cd "$TMP" && /home/tonny/projects/init-project/install.sh --force --skip-skills )
cd "$TMP" && git init && git add . && git commit -m "Bootstrap from base-files"
echo "Exit: $?"
```

Expected: `Exit: 0`. The first commit after bootstrap must succeed.

---

## Open follow-ups (deferred — explicitly out of scope)

- LICENSE, CONTRIBUTING.md, CHANGELOG.md seeds — track in a separate plan.
- Coverage upload, dependabot config, release automation — separate ADRs.
- pre-commit autoupdate scheduling (manual for now; doc'd in QUALITY.md).
- Multi-OS / multi-runtime CI matrix.
