# Bootstrap Completeness: pre-commit + CI + standard dotfiles

**Date:** 2026-05-24
**Status:** Draft — pending user review
**Scope:** This `init-project` template AND every project bootstrapped from it.
**Supersedes/Touches:** ADR-0000 (extends — does not reverse). A new ADR-0001 will be created alongside this work to lock the quality-gate ownership shift.

## Problem

The current template is strong on AI-agent integration (orchestrator, hooks, ADR, plan-first pipeline) but is incomplete as a *general* project bootstrap when measured against widely-used conventions (cookiecutter, copier, `rails new`, `create-*`). Three concrete defects:

1. **First-commit failure on Python projects.** `langs/python/.claude/settings.json:11` runs `pytest -q` on `git commit`; a freshly bootstrapped project has no tests yet, so pytest exits 5 ("no tests collected") and the hook denies the commit. The bootstrap walkthrough (`install.sh:104`) literally suggests running this commit immediately. Rails (`bin/rails test`) and Go (`go test ./...`) have the same structural risk on empty projects.
2. **Quality gates are Claude-Code-locked.** All pytest/ruff, `go test`/golangci-lint, and `bin/rails test`/rubocop enforcement lives inside `.claude/settings.json` PreToolUse hooks. The moment any human or tool runs `git commit` outside a Claude Code session — terminal, VS Code source-control UI, JetBrains, GitHub web editor, CI — there is zero enforcement. The template effectively promises quality only inside one specific tool.
3. **Standard dotfiles missing.** No `.editorconfig` (multi-editor whitespace drift), no language-specific `.gitignore` (downstream projects end up committing `__pycache__/`, `log/`, `node_modules/`, `bin/`), no CI workflow file (no enforcement on push/PR), no `.pre-commit-config.yaml` (no git-native gate).

Root cause: the template treats Claude Code as the universal quality gate. That is structurally fragile and inconsistent with how mainstream language ecosystems define quality gates (pre-commit + CI).

## Goals

- The first `git commit` after `install.sh` succeeds on every supported language with no manual intervention.
- Quality gates run for *any* commit, regardless of the tool that initiated it (Claude Code, terminal, IDE, CI).
- `pre-commit` yaml is the single source of truth for fast checks. CI re-uses the same yaml. Claude hooks do not duplicate it.
- Three supported languages (Python, Go, Rails) all get the same treatment via the existing `common/ + langs/<lang>/` overlay pattern.
- No new global dependency beyond `pre-commit` (Python tool, installable via `pip` / `pipx` / `uvx`).

## Non-Goals

- Multi-OS or multi-runtime CI matrix builds. ubuntu-latest only, single runtime version per language.
- Coverage upload, release automation, dependabot config. Future ADRs.
- Replacing GitHub Actions with a different CI provider. GitHub Actions is the assumed target (consistent with the existing `gh`-cli usage and `push2gh` skill).
- Adding a new language overlay. Only the three existing (Python, Go, Rails).
- Migrating the Orchestrator hooks (SessionStart/UserPromptSubmit/PreToolUse stale-check). They are unrelated to quality gating.

## Decisions

### D1. Quality-gate source of truth — pre-commit yaml

`.pre-commit-config.yaml` per language overlay owns all fast-check definitions. CI calls `pre-commit run --all-files` to re-use the same yaml. Claude Code language hooks drop the PreToolUse `Bash(git commit*)` gates entirely (they become redundant once pre-commit is git-native). Format-on-save PostToolUse hooks are kept — they give immediate edit feedback that pre-commit cannot.

**Rationale:** DRY (`RULES.md`), removes Claude-Code lock-in, matches language-ecosystem standard tooling, consistent with ADR-0000's "context-injection rather than hard-block" philosophy applied uniformly.

### D2. Pre-commit scope — fast checks only, no tests

Pre-commit runs: language-agnostic hygiene hooks (`trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-json`, `check-added-large-files`, `mixed-line-ending`, `detect-private-key`, `detect-aws-credentials`) plus the language-specific linter/formatter (ruff / gofmt+golangci-lint / rubocop). **Tests run in CI only**, not in pre-commit.

**Rationale:** Pre-commit's official guidance is "fast checks at commit time, slow checks in CI." Confining to fast checks also makes the pytest-exit-5 class of bugs disappear at the pre-commit layer — there is no test runner to mis-handle an empty test suite. Empty-project first commit succeeds trivially.

### D3. CI structure — per-language overlay, single job, ubuntu-latest

Each language overlay ships `.github/workflows/ci.yml`. The yaml is complete and self-contained per language (no shared common include). Triggers: `pull_request` to `main` and `push` to `main`. Steps: checkout → setup runtime → install deps → `pre-commit run --all-files` → language-standard test command.

**Rationale:** Matches the existing `common/ + langs/<lang>/` composition pattern. Each language's runtime setup (`uv` / `setup-go` / `setup-ruby`) and test invocation differ enough that a unified yaml with conditional dispatch costs more readability than it saves DRY.

### D4. Standard dotfiles — common universal + per-language specific

- `common/.editorconfig` — universal (one file, copied to every project regardless of language). Standard content: utf-8, lf line endings, 2-space default, 4-space for Python/Go/Makefile.
- `langs/<lang>/.gitignore` — sourced verbatim from the upstream `github/gitignore` repo for the language, with only a header comment added that pins the source path and commit SHA. No trimming, no edits to the body. Battle-tested coverage; refreshes are mechanical.

### D5. ADR-0001 captures the locked decision

A new ADR titled "Quality gates owned by pre-commit + CI; Claude hooks are advisory" is drafted in the same PR. It locks D1 so future sessions cannot quietly revert the migration without an explicit supersede.

### D6. Single PR for the entire migration

All file additions, modifications, and the ADR ship in one PR. Splitting would either leave the template in a half-migrated state (bug #1 fixed but gates still Claude-locked) or duplicate review effort across coupled changes.

## Solution Overview

### File map after migration

```
init-project/
├── common/
│   ├── .editorconfig                         [new]   universal whitespace/eol
│   └── docs/standards/QUALITY.md             [modify] document the new gating layers
├── langs/
│   ├── python/
│   │   ├── .gitignore                        [new]   from github/gitignore/Python.gitignore
│   │   ├── .pre-commit-config.yaml           [new]   hygiene + ruff
│   │   ├── .github/workflows/ci.yml          [new]   uv → pre-commit → pytest
│   │   └── .claude/settings.json             [modify] remove PreToolUse pytest+ruff deny gates
│   ├── go/
│   │   ├── .gitignore                        [new]   from github/gitignore/Go.gitignore
│   │   ├── .pre-commit-config.yaml           [new]   hygiene + gofmt + golangci-lint
│   │   ├── .github/workflows/ci.yml          [new]   setup-go → pre-commit → go test
│   │   └── .claude/settings.json             [modify] remove PreToolUse go-test+golangci deny gates
│   └── rails/
│       ├── .gitignore                        [new]   from github/gitignore/Ruby.gitignore + Rails.gitignore
│       ├── .pre-commit-config.yaml           [new]   hygiene + rubocop
│       ├── .github/workflows/ci.yml          [new]   setup-ruby → pre-commit → bin/rails test
│       └── .claude/settings.json             [modify] remove PreToolUse rails-test+rubocop deny gates
├── docs/
│   └── decisions/
│       ├── ADR-0001-quality-gates-owned-by-precommit.md   [new]
│       └── README.md                          [modify] index entry for ADR-0001
├── README.md                                  [modify] mention .editorconfig/.gitignore/.pre-commit/CI in produced layout
├── PROJECT_STATE.md                           [modify] update Active Spec / Active Plan paths
└── tests/
    ├── smoke_python.sh                        [modify] verify new files copied, verify empty-project commit succeeds
    ├── smoke_go.sh                            [modify] same
    ├── smoke_rails.sh                         [modify] same
    └── test_orchestrator_hooks.sh             [verify-only] confirm orchestrator hooks still load
```

`lib/copy-files.sh` requires **no change** — it already walks the overlay with `find -type f -print0`, which discovers dotfiles (`.editorconfig`, `.gitignore`, `.pre-commit-config.yaml`) and traverses hidden directories (`.github/`). Verified by reading `lib/copy-files.sh:53-62`.

### Per-component design

#### `.pre-commit-config.yaml` (per language overlay)

Common base hooks (identical across all three language overlays — small DRY cost, large simplicity gain):

```yaml
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
```

Per-language additions appended below the common base:

- **Python:** `astral-sh/ruff-pre-commit` (ruff check + ruff format)
- **Go:** `dnephin/pre-commit-golang` (gofmt, go vet) + local `golangci-lint` hook
- **Rails:** local `rubocop` hook (via `bundle exec rubocop`)

`rev:` pins for every external repo are required (pre-commit's `autoupdate` is run as part of the bootstrap process, not at commit time).

#### `.github/workflows/ci.yml` (per language overlay)

Template structure (Python shown; Go/Rails analogous):

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
      - uses: astral-sh/setup-uv@v3
      - run: uv sync --all-extras --dev
      - run: uv tool install pre-commit
      - run: uv run pre-commit run --all-files
      - run: uv run pytest -q
```

Go: `actions/setup-go@v5` + `go mod download` + `pre-commit run --all-files` + `go test ./...`.
Rails: `ruby/setup-ruby@v1` (`bundler-cache: true`) + `pre-commit run --all-files` + `bin/rails test`.

#### `common/.editorconfig`

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

#### `.gitignore` per language overlay

Sourced from `github/gitignore` upstream at commit pin `<latest as of 2026-05-24>` (the writing-plans phase will pin the exact commit SHAs):

- Python: `github/gitignore/Python.gitignore`
- Go: `github/gitignore/Go.gitignore`
- Rails: `github/gitignore/Rails.gitignore` (which already extends `Ruby.gitignore`)

A 1-line header comment in each file states the upstream source and commit SHA so future refreshes are mechanical.

#### Claude `.claude/settings.json` migration (per language)

For each of Python/Go/Rails, **delete** the entire `PreToolUse.Bash` block (the `git commit*` gates). **Keep** the entire `PostToolUse.Write|Edit` block (the format-on-save). Net change per file: ~15 lines removed, 0 lines added.

#### ADR-0001

```markdown
# ADR-0001: Quality gates owned by pre-commit + CI; Claude hooks advisory

- **Status:** Accepted
- **Date:** 2026-05-24
- **Supersedes:** (none — extends ADR-0000)
- **Superseded by:** (none)

## Context
[Restates problems #1, #2 from this spec at ADR length.]

## Decision
Pre-commit (.pre-commit-config.yaml) is the single source of truth for fast quality
checks at commit time. CI (.github/workflows/ci.yml) re-runs pre-commit + executes
the test suite. Claude Code .claude/settings.json hooks no longer gate git commits;
the language-specific PreToolUse Bash hooks are removed. PostToolUse format-on-save
hooks are retained as edit-time feedback.

## Consequences
Positive: gates run regardless of which tool initiates the commit; single source
of truth across local and CI; empty-project first commit succeeds.
Negative: requires pre-commit binary installed (pip/pipx/uvx). Documented in
QUALITY.md and install.sh dependency check.
```

### Updates to `common/docs/standards/QUALITY.md`

Add a section "Quality gate layering" that explicitly documents the four layers and their roles:

| Layer | When | Owner | Strength |
|---|---|---|---|
| Edit-time format | On file save inside Claude Code | `.claude/settings.json` PostToolUse | Auto-fix, no block |
| Commit-time fast checks | On `git commit` (any tool) | `.pre-commit-config.yaml` via installed git hook | Block on violation |
| CI fast + slow checks | On PR / push to main | `.github/workflows/ci.yml` | Block merge |
| Orchestrator hooks (unrelated) | Session start, prompt submit, stale state | `.claude/hooks/*.sh` | Soft inject / warn |

### Updates to `install.sh` / `lib/check-deps.sh`

`lib/check-deps.sh` already checks per-language tools. Add a single check for `pre-commit` (any of `command -v pre-commit`, `uvx --help`, `pipx --help` satisfies). The `install.sh` "next:" hint (`install.sh:104`) is extended:

```
next: git init && git add . && git commit -m 'Bootstrap from base-files'
      then: pre-commit install   # registers the git hook
```

The `pre-commit install` step is **not** automated by `install.sh` because it requires the project to be a git repo, which it may not be at the moment install.sh runs. A README note + the install.sh `next:` hint make it explicit.

## Migration / Rollout

1. Author this spec (Phase 3 — current step).
2. Write implementation plan (Phase 4) via `superpowers:writing-plans`. The plan will sequence file additions/modifications atomically per `RULES.md` "Tidy First" — structural moves separate from behavioral changes.
3. Execute plan (Phase 5) under TDD. Each language overlay's smoke test is the verification anchor: after install.sh into a fresh tempdir, `git init && git add . && git commit -m bootstrap` must succeed.
4. Update PROJECT_STATE.md Active Spec/Plan via `/state-sync` at Phase 3→4 and Phase 4→5 transitions.
5. After merge: `/decide` to confirm ADR-0001 is Accepted. `/state-sync` clears the work from Active Work.

## Risk & Rollback

**R1 — pre-commit binary not installed on user machine.**
Mitigation: `check-deps.sh` warns; `install.sh` "next:" hint shows install command. Pre-commit is a Python package, available everywhere Python is. Likelihood of true blocker: low.

**R2 — pre-commit yaml gets out of date as upstream hooks evolve.**
Mitigation: `rev:` pins are explicit; `pre-commit autoupdate` is the maintenance command. Documented in QUALITY.md.

**R3 — CI run cost increase.**
Mitigation: single job, ubuntu-latest only, no matrix. Each language's CI is independent so a Python project does not pay Go's CI cost. Effective minutes per PR: <5.

**R4 — Removal of Claude PreToolUse gates loses the rich `permissionDecisionReason` UX inside Claude sessions.**
Mitigation: pre-commit stderr is captured by Claude's Bash tool; the model reads it and self-corrects. UX is plainer but information-equivalent.

**Rollback strategy:** the change is a single PR; revert restores the prior state. ADR-0001 status flips to Superseded by a new ADR-0002 if reverted, per ADR convention.

## Test Plan

Verification anchors (each must pass before claiming completion):

1. `tests/smoke_python.sh` — install into empty dir, `git init && git add . && git commit` succeeds without any test files present.
2. `tests/smoke_go.sh` — same for Go (empty `go.mod` project).
3. `tests/smoke_rails.sh` — same for Rails (skeletal Rails app).
4. New test `tests/test_pre_commit_yaml.sh` — for each language, validate the produced `.pre-commit-config.yaml` parses (use `python -c 'import yaml; yaml.safe_load(open(...))'` or `pre-commit validate-config`).
5. New test `tests/test_ci_yaml.sh` — for each language, validate `.github/workflows/ci.yml` parses as valid GitHub Actions yaml (basic `yaml.safe_load`; full action validation deferred to first real CI run).
6. Existing `tests/test_orchestrator_hooks.sh` continues to pass (orchestrator hooks untouched).

## Open Items (intentionally deferred)

- Coverage upload (Codecov / Coveralls)
- Release automation (semantic-release / release-please)
- Dependabot config
- Pre-commit `autoupdate` scheduling
- LICENSE, CONTRIBUTING.md, CHANGELOG.md seeds (separately tracked — lower priority than the three items in scope)
