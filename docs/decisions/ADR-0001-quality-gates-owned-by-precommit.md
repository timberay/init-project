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
