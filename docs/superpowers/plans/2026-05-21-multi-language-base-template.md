# Multi-Language Base Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `~/projects/00.base-files/` so a single `install.sh` bootstraps any new Ruby on Rails / Python / Go project with the correct combination of common guidance + language-specific overlay + recommended Claude Code plugins.

**Architecture:** Source-of-truth lives in `common/` (language-neutral) and `langs/<rails|python|go>/` (overlays). A bash entry point `install.sh` orchestrates five phases (detect → check-deps → copy → merge-settings → install-skills), each delegated to a focused module in `lib/`. Hooks for the target project's `.claude/settings.json` are produced by deep-merging the common JSON with the chosen language's JSON via `jq`.

**Tech Stack:** Bash 4+, `jq`, `git`, optional `gh`. Plugin installation uses the official `claude plugin` CLI. No new runtime dependencies introduced; the installer only orchestrates tools the user already has (or warns when absent).

**Design spec:** [`docs/superpowers/specs/2026-05-21-multi-language-base-template-design.md`](../specs/2026-05-21-multi-language-base-template-design.md)

---

## File Map

### Created (new)
- `install.sh` — entry point, parses flags, runs five phases in order
- `README.md` — usage, flag reference, troubleshooting
- `VERSION` — `0.1.0`
- `.gitignore` — exclude `*.bak.*` backups and editor noise
- `common/CLAUDE.md` — language-neutral global guidance
- `common/docs/standards/RULES.md` — copy of current `docs/standards/RULES.md`
- `common/docs/standards/WORKFLOW.md` — six-phase pipeline (with one Rails reference generalized)
- `common/docs/standards/QUALITY.md` — principles only, no tool names
- `common/docs/standards/REVIEW.md` — manual code-review checklist (extracted from current QUALITY.md)
- `common/.claude/settings.json` — graphify + pipeline-reminder hooks only
- `common/.claude/hooks/pipeline-reminder.txt` — copy of current file
- `langs/rails/docs/standards/STACK.md` — current `docs/standards/STACK.md` moved verbatim
- `langs/rails/docs/standards/TOOLS.md` — current `docs/standards/TOOLS.md` moved verbatim
- `langs/rails/.claude/settings.json` — current Rails-specific hooks only
- `langs/python/docs/standards/STACK.md` — new (FastAPI/Django, uv, ruff)
- `langs/python/docs/standards/TOOLS.md` — new
- `langs/python/.claude/settings.json` — new (pytest + ruff hooks)
- `langs/go/docs/standards/STACK.md` — new (net/http or chi, go modules)
- `langs/go/docs/standards/TOOLS.md` — new
- `langs/go/.claude/settings.json` — new (go test + golangci-lint hooks)
- `lib/log.sh` — color logger
- `lib/detect-language.sh` — manifest sniffer + interactive fallback
- `lib/check-deps.sh` — OS tool presence checks (no install)
- `lib/copy-files.sh` — copy with timestamped backups + per-file conflict prompt
- `lib/merge-settings.sh` — jq-based deep merge for two `settings.json` files
- `lib/install-skills.sh` — `claude plugin marketplace add` + `install` orchestration
- `tests/run_all.sh` — runs every `tests/test_*.sh` and reports pass/fail
- `tests/test_log.sh` — verifies `lib/log.sh` functions emit expected formatting
- `tests/test_detect_language.sh` — verifies detection across the four input scenarios
- `tests/test_check_deps.sh` — verifies check_deps reports presence/absence accurately
- `tests/test_copy_files.sh` — verifies copy + backup behavior in a tmp dir
- `tests/test_merge_settings.sh` — verifies deep-merge result includes hooks from both inputs
- `tests/test_install_skills.sh` — verifies idempotent marketplace/plugin commands (mocks `claude`)
- `tests/smoke_rails.sh`, `tests/smoke_python.sh`, `tests/smoke_go.sh`, `tests/smoke_empty.sh` — end-to-end scenarios from spec §8 step 5

### Removed (after migration)
- `CLAUDE.md` — superseded by `common/CLAUDE.md` (installer will copy this to a target project)
- `docs/standards/RULES.md` — moved to `common/`
- `docs/standards/WORKFLOW.md` — moved to `common/`
- `docs/standards/QUALITY.md` — rewritten into `common/QUALITY.md` + `common/REVIEW.md`
- `docs/standards/STACK.md` — moved to `langs/rails/`
- `docs/standards/TOOLS.md` — moved to `langs/rails/`
- `.claude/settings.json` — split into `common/.claude/settings.json` + `langs/rails/.claude/settings.json`
- `.claude/hooks/pipeline-reminder.txt` — moved to `common/.claude/hooks/`

After cleanup the project root contains only `install.sh`, `README.md`, `VERSION`, `.gitignore`, and the four directories `common/`, `langs/`, `lib/`, `tests/` (plus `docs/superpowers/` for the spec and plan themselves).

---

## Task 0: Initialize git repository

**Files:**
- Create: `/home/tonny/projects/00.base-files/.gitignore`
- Init: `/home/tonny/projects/00.base-files/.git/`

- [ ] **Step 1: Initialize the repo**

```bash
cd /home/tonny/projects/00.base-files
git init -b main
```

Expected output: `Initialized empty Git repository in /home/tonny/projects/00.base-files/.git/`

- [ ] **Step 2: Create `.gitignore`**

Write `/home/tonny/projects/00.base-files/.gitignore` with content:

```gitignore
# Installer backups created by install.sh --force / per-file overwrite prompt
*.bak.[0-9]*

# Editor / OS noise
.DS_Store
*.swp
*~
.idea/
.vscode/

# Test artefacts
tests/tmp/
```

- [ ] **Step 3: Verify gitignore is recognised**

```bash
cd /home/tonny/projects/00.base-files
echo "scratch" > foo.bak.20260521-000000
git status --short
```

Expected: `foo.bak.20260521-000000` does NOT appear in status output. Delete the scratch file:

```bash
rm foo.bak.20260521-000000
```

- [ ] **Step 4: Stage the existing template files and the gitignore, then commit a baseline**

```bash
cd /home/tonny/projects/00.base-files
git add .gitignore CLAUDE.md docs/ .claude/
git status
```

Expected: all current files staged. Then commit:

```bash
git commit -m "chore: baseline before multi-language refactor"
```

---

## Task 1: Move Rails STACK.md into the rails overlay

**Files:**
- Move: `docs/standards/STACK.md` → `langs/rails/docs/standards/STACK.md`

- [ ] **Step 1: Create the destination directory**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p langs/rails/docs/standards
```

- [ ] **Step 2: Move the file with `git mv`**

```bash
git mv docs/standards/STACK.md langs/rails/docs/standards/STACK.md
git status
```

Expected: status shows `renamed: docs/standards/STACK.md -> langs/rails/docs/standards/STACK.md`.

- [ ] **Step 3: Verify content unchanged**

```bash
head -1 langs/rails/docs/standards/STACK.md
wc -l langs/rails/docs/standards/STACK.md
```

Expected: first line matches whatever the original `STACK.md` started with; line count matches the pre-move file size.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: move Rails STACK.md into rails overlay"
```

---

## Task 2: Move Rails TOOLS.md into the rails overlay

**Files:**
- Move: `docs/standards/TOOLS.md` → `langs/rails/docs/standards/TOOLS.md`

- [ ] **Step 1: Move the file**

```bash
cd /home/tonny/projects/00.base-files
git mv docs/standards/TOOLS.md langs/rails/docs/standards/TOOLS.md
git status
```

Expected: status shows the rename.

- [ ] **Step 2: Commit**

```bash
git commit -m "refactor: move Rails TOOLS.md into rails overlay"
```

---

## Task 3: Extract Rails-specific hooks into the rails overlay

**Files:**
- Create: `langs/rails/.claude/settings.json`

- [ ] **Step 1: Create the destination directory**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p langs/rails/.claude
```

- [ ] **Step 2: Write the Rails-only `settings.json`**

Write `/home/tonny/projects/00.base-files/langs/rails/.claude/settings.json` with content:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": "export PATH=\"$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH\"; if [ -x bin/rails ]; then bin/rails test > /tmp/test_output.txt 2>&1; rc=$?; if [ $rc -ne 0 ]; then jq -n --rawfile out /tmp/test_output.txt '{hookSpecificOutput:{hookEventName:\"PreToolUse\",permissionDecision:\"deny\",permissionDecisionReason:(\"Rails test failed. Diagnose the failures, fix the code, and retry the commit.\\n\\n--- bin/rails test output ---\\n\" + $out)}}'; fi; fi",
            "timeout": 120,
            "statusMessage": "Running tests before commit..."
          },
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": "export PATH=\"$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH\"; if [ -x bin/rubocop ]; then bin/rubocop --format quiet > /tmp/rubocop_output.txt 2>&1; rc=$?; if [ $rc -ne 0 ]; then jq -n --rawfile out /tmp/rubocop_output.txt '{hookSpecificOutput:{hookEventName:\"PreToolUse\",permissionDecision:\"deny\",permissionDecisionReason:(\"Rubocop violations found. Run `bin/rubocop -a` to auto-fix, manually address any remaining issues, re-stage, and retry the commit.\\n\\n--- bin/rubocop --format quiet output ---\\n\" + $out)}}'; fi; fi",
            "timeout": 60,
            "statusMessage": "Running rubocop before commit..."
          }
        ]
      }
    ],
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

- [ ] **Step 3: Validate JSON**

```bash
jq empty langs/rails/.claude/settings.json && echo "JSON OK"
```

Expected: `JSON OK`.

- [ ] **Step 4: Commit**

```bash
git add langs/rails/.claude/settings.json
git commit -m "refactor: extract Rails-specific hooks into rails overlay"
```

---

## Task 4: Copy RULES.md verbatim into common/

**Files:**
- Move: `docs/standards/RULES.md` → `common/docs/standards/RULES.md`

- [ ] **Step 1: Create destination directory**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p common/docs/standards
```

- [ ] **Step 2: Move the file**

```bash
git mv docs/standards/RULES.md common/docs/standards/RULES.md
git status
```

Expected: rename shown.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: move RULES.md into common (no edits)"
```

---

## Task 5: Move WORKFLOW.md into common/ and generalize one Rails reference

**Files:**
- Move: `docs/standards/WORKFLOW.md` → `common/docs/standards/WORKFLOW.md`
- Edit (after move): `common/docs/standards/WORKFLOW.md:26`

- [ ] **Step 1: Move the file**

```bash
cd /home/tonny/projects/00.base-files
git mv docs/standards/WORKFLOW.md common/docs/standards/WORKFLOW.md
```

- [ ] **Step 2: Generalize the one Rails-specific line**

Open `common/docs/standards/WORKFLOW.md` and find line 26 (inside the Phase 3 section). Change:

```
- **Answers**: Rails patterns, concurrency, caching, test strategy
```

to:

```
- **Answers**: framework patterns, concurrency, caching, test strategy (see `STACK.md` for the language-specific concerns)
```

- [ ] **Step 3: Verify no other Rails-specific terms remain**

```bash
grep -inE "rails|rubocop|minitest|capybara|solid queue|solid cache|tailwind" common/docs/standards/WORKFLOW.md
```

Expected: no output (exit code 1).

- [ ] **Step 4: Commit**

```bash
git add common/docs/standards/WORKFLOW.md
git commit -m "refactor: move WORKFLOW.md into common and generalize Phase 3 reference"
```

---

## Task 6: Write the language-neutral QUALITY.md

**Files:**
- Create: `common/docs/standards/QUALITY.md`
- Delete (next task handles): old `docs/standards/QUALITY.md`

- [ ] **Step 1: Write the new file**

Write `/home/tonny/projects/00.base-files/common/docs/standards/QUALITY.md` with content:

````markdown
# Evaluation Criteria

Testing strategy, security principles, accessibility, and performance guidelines.
This file contains language-neutral principles only — concrete tools, commands,
and framework-specific guardrails live in the language overlay's `TOOLS.md` and
`STACK.md`.

## Testing Strategy

### Test Pyramid (maintain this ratio)

- **Unit** (majority): Pure functions, models, services
- **Integration** (moderate): Cross-component behavior with real I/O at the edge
  (database, in-process HTTP, queue) and stubbed external networks
- **System / E2E** (few): Major user scenarios only

### Test Coverage

- Every new feature must include corresponding tests
- Bug fixes must include a regression test that fails before the fix and passes
  after it
- Tests document the contract — name them after the behavior they assert, not
  after the function they happen to call

> Concrete test framework, runner command, and HTTP stubbing tool are defined
> in `TOOLS.md` (language overlay).

## Security Best Practices

### Universal Principles

- **No secrets in git** — `.env*`, credentials, tokens belong in a secrets manager
  or platform-managed encrypted store. Never commit a `.env` with real values.
- **Validate at boundaries** — every datum entering the system from the outside
  (HTTP body, query string, CLI argument, file upload, external API response)
  must be parsed and validated before any business logic touches it.
- **Least privilege** — DB user, API token, IAM role: each holds only the
  permissions it actually exercises. Production secrets are not reused in dev.
- **Rate-limit anything public** — login, signup, password reset, public APIs.
  Limits live in code, not in a manually-tuned reverse-proxy config.
- **Output encoding** — never concatenate untrusted strings into HTML, SQL, or
  shell commands. Use the framework's escaping/parameterization helper.
- **No raw user content reflected without sanitization** — text rendered into
  HTML or PDF passes through the framework's safe-string mechanism.
- **Constant-time comparison** for tokens, MACs, and passwords.

> Framework-specific guardrails (CSRF tokens, parameter whitelisting, ORM
> placeholder syntax, template auto-escape, regex-DoS limits, rate-limit
> middleware names) live in the language overlay's `STACK.md`.

## Accessibility Standards

### Status Indicators

Always display text labels alongside emoji statuses (e.g. "Red circle Not
recommended" not just "Red circle"). Add ARIA labels for screen readers.

### Keyboard Navigation

Ensure all interactive elements (buttons, form inputs, links) are reachable via
the Tab key. Checklist question answers must be selectable via keyboard.

### Form Inputs

- NUMBER fields use `inputmode="numeric"` for mobile keyboard optimization
- Display unit suffix (%, won, year) adjacent to the input

### Tooltips

Domain-specific terminology (legal, medical, financial, jargon) should have
inline help-text tooltips, accessible via hover (desktop) and tap (mobile).

### Color Independence

Never rely on color alone to convey status. Always pair with text and/or icons.

### Responsive Design

Mobile-first approach. Ensure touch targets are at least 44x44 px.

### Automated Accessibility Checks

Wire an automated accessibility scanner into the system-test suite when one
exists for the framework. Run it on the critical pages on every CI run. The
exact integration is documented in the language overlay's `TOOLS.md`.

## Performance Guidelines

### Universal Principles

- **Measure before caching** — cache only what is both hot and slow (>50 ms
  re-render cost on a request path; underlying data changing less than once
  per request).
- **Prevent N+1** — collection renders issue O(1) queries, not O(n). When in
  doubt, inspect the development log for repeated SELECT patterns.
- **Off-request work for heavy I/O** — long external calls (LLM inference,
  scraping, PDF generation, image processing) move to background jobs. The
  user sees a streamed update or polled state, never a blocked request.
- **Index columns used in WHERE/ORDER BY** on hot queries.
- **Bundle size discipline** — JS/CSS bundles measured per route; growth
  beyond an agreed budget requires justification.

> The cache backend, queue runner, ORM helpers, and bundle analyzer are listed
> in the language overlay's `STACK.md` / `TOOLS.md`.

## Evidence-Driven Self-Diagnosis

You have no eyes or memory beyond what you explicitly capture. Logs and
screenshots are the only evidence you can use to diagnose problems
autonomously — if you did not record it, it does not exist for you.

### Why This Matters

- You cannot re-observe a past UI state or a transient error after it
  disappears.
- Detailed evidence lets you form hypotheses and verify fixes without asking
  humans.
- Vague or missing logs force you to guess, which violates the TDD principle of
  working from facts.

### What to Capture

| Situation              | What to Record                                         |
|------------------------|--------------------------------------------------------|
| Running a command      | Full stdout/stderr output, not a summary               |
| UI change              | Screenshot before AND after                            |
| Test failure           | Complete error message, stack trace, and command used  |
| Unexpected behavior    | Steps to reproduce, expected vs. actual result         |
| External API call      | Request payload, response status, and response body    |

For diagnosis workflow, follow the `systematic-debugging` skill.

## Pre-commit Failure Recovery

This project enforces commit gates via Claude Code `PreToolUse` hooks
(`.claude/settings.json`). The exact commands are language-specific — see
`TOOLS.md`. The recovery workflow is universal:

- **Linter violations**: run the auto-fix command, manually resolve the rest,
  re-stage, retry the commit.
- **Test failure**: diagnose the failing test, fix the code, verify locally
  with the test command, retry the commit.
- **Multiple issues**: fix lint first (cheap), then tests, then retry.
- **Never** bypass with `--no-verify` to escape a failing hook. If a hook is
  wrong, fix the hook in a separate commit.

For the code-review checklist that gates merging, see `REVIEW.md`.
````

- [ ] **Step 2: Verify no language-specific terms remain**

```bash
grep -inE "rails|rubocop|minitest|capybara|solid queue|tailwind|rack::attack|pytest|ruff|golangci" common/docs/standards/QUALITY.md
```

Expected: no output (exit code 1).

- [ ] **Step 3: Stage and commit**

```bash
git add common/docs/standards/QUALITY.md
git commit -m "feat(common): add language-neutral QUALITY.md with principles only"
```

---

## Task 7: Extract REVIEW.md (manual review checklist) into common/

**Files:**
- Create: `common/docs/standards/REVIEW.md`

- [ ] **Step 1: Write the file**

Write `/home/tonny/projects/00.base-files/common/docs/standards/REVIEW.md` with content:

````markdown
# Code Review Checklist

Use this checklist before requesting a merge or approving someone else's PR.
The automated gate (test runner, linter, security scanner) is enforced by the
pre-commit hooks in `.claude/settings.json` — see the language overlay's
`TOOLS.md` for the exact commands. This file lists the manual checks a human
(or an AI reviewer) must perform.

## Automated (enforced by pre-commit hooks)

The hooks listed in `.claude/settings.json` MUST pass before any commit lands.
See `TOOLS.md` in the language overlay for the exact command set. Typical
gates:

- [ ] All tests pass
- [ ] No linting errors
- [ ] No security warnings (static analyzer / dependency audit)
- [ ] Database seeds / fixtures load cleanly in a fresh environment

If any of these are missing for the language, document why in `TOOLS.md`
rather than skipping the check.

## Manual Review

- [ ] Structural and behavioral changes are in separate commits (Tidy First)
- [ ] New features have corresponding tests at the right level of the pyramid
- [ ] Public API changes are reflected in the relevant documentation
- [ ] Accessibility requirements (see `QUALITY.md`) are met for UI changes
- [ ] No N+1 queries introduced (or one is explicitly justified)
- [ ] Caching applied where appropriate (hot path + slow + stable data)
- [ ] Background-job work used for any heavy external I/O on a request path
- [ ] Error messages are user-facing where appropriate (no raw stack traces
      reaching end-users)
- [ ] Logs include enough context for post-hoc diagnosis (see `QUALITY.md` ->
      Evidence-Driven Self-Diagnosis)
- [ ] No secrets, tokens, or production URLs committed
- [ ] Feature flags or migrations are reversible (or the irreversibility is
      explicit in the PR description)

## When to block

Block the merge when any of the following is true; otherwise prefer
"approve with comments":

- A correctness bug demonstrable by an existing or trivially-added test
- A security regression (auth bypass, secret leak, injection vector)
- A performance regression on a hot path with no mitigating plan
- An API break with no migration path documented
- A test deleted or weakened without justification
````

- [ ] **Step 2: Verify language-neutral**

```bash
grep -inE "rails|rubocop|minitest|capybara|solid queue|tailwind|rack::attack|pytest|ruff|golangci" common/docs/standards/REVIEW.md
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add common/docs/standards/REVIEW.md
git commit -m "feat(common): add REVIEW.md with manual review checklist"
```

---

## Task 8: Write the language-neutral common/CLAUDE.md

**Files:**
- Create: `common/CLAUDE.md`

- [ ] **Step 1: Write the file**

Write `/home/tonny/projects/00.base-files/common/CLAUDE.md` with content:

````markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Non-Negotiable Rules

- **Korean** for explanations and conversation; **English** for code, markdown,
  YAML, commit messages
- **TDD**: Red-Green-Refactor for every task. Write a failing test first.
- **Tidy First**: NEVER mix structural changes (refactoring) and behavioral
  changes (new logic) in a single commit
- **Small Commits**: Commit every time a test passes or a refactoring is done

## Standards Reference

Detailed standards are in `docs/standards/`. **Read the relevant document(s)
before starting work.**

| Document      | Description                                                                       |
|---------------|-----------------------------------------------------------------------------------|
| `RULES.md`    | DRY, Tidy First, documentation rules, AI instruction writing guidelines           |
| `WORKFLOW.md` | Six-phase pipeline (product → architecture → design → tasks → execute → ship)     |
| `QUALITY.md`  | Testing strategy, security principles, accessibility, performance                 |
| `REVIEW.md`   | Code review checklist                                                             |
| `STACK.md`    | **Language overlay** — tech stack, framework patterns                             |
| `TOOLS.md`    | **Language overlay** — dev commands, linter, test runner, security scanner        |

> `STACK.md` and `TOOLS.md` were installed from the language overlay at
> bootstrap time. To switch language later, re-run `install.sh --lang <other>`
> from the project root.

## Pre-commit Failure Recovery

When a pre-commit hook fails, fix it yourself and retry — do not stop and ask
the user. **Details:** see `QUALITY.md → Pre-commit Failure Recovery` and the
language-specific commands in `TOOLS.md`.

## Pipeline Phases

For new feature work, follow the six-phase pipeline (`WORKFLOW.md`). Skip only
for bug fixes, refactors, or small tweaks. A `UserPromptSubmit` hook in
`.claude/settings.json` injects the phase reminder when a feature-request
keyword is detected.

## Task → Required Reading

Before starting work, read the documents mapped to your task type:

| Task Type                  | Must Read                                                |
|----------------------------|----------------------------------------------------------|
| Feature implementation     | RULES, STACK                                             |
| UI / Frontend / Styling    | STACK, QUALITY (Accessibility)                           |
| Bug fix / Debugging        | QUALITY                                                  |
| Testing                    | QUALITY (Testing Strategy)                               |
| API integration            | STACK (Adapter / Integration Pattern), TOOLS             |
| Authentication / OAuth     | STACK (Authentication), QUALITY (Security)               |
| Database / Migration       | STACK (Database & Infrastructure), TOOLS (DB commands)   |
| Deployment / DevOps        | STACK (Deployment), TOOLS (Deployment commands)          |
| Code review / PR           | REVIEW                                                   |

## Behavioral Guidelines

These guidelines reduce common LLM coding mistakes. They bias toward caution
over speed; use judgment for trivial tasks.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes,
simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it
work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer
rewrites due to overcomplication, and clarifying questions come before
implementation rather than after mistakes.

## graphify

This project may have a graphify knowledge graph at `graphify-out/`.

Rules:
- Before answering architecture or codebase questions, read
  `graphify-out/GRAPH_REPORT.md` for god nodes and community structure
- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw
  files
- For cross-module "how does X relate to Y" questions, prefer
  `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or
  `graphify explain "<concept>"` over grep — these traverse the graph's
  EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep
  the graph current (AST-only, no API cost)

## Recommended Claude Code Plugins

These are auto-installed by `install.sh` (skip with `--skip-skills`):

| Plugin                       | Marketplace                | Purpose                                      |
|------------------------------|----------------------------|----------------------------------------------|
| `superpowers`                | `claude-plugins-official`  | Brainstorming, plans, TDD, debugging, review |
| `code-review`                | `claude-plugins-official`  | Branch / PR review                           |
| `andrej-karpathy-skills`     | `karpathy-skills`          | Karpathy's coding-mistake guardrails         |

`graphify` is verified (not installed) by the installer; install it manually if
absent.
````

- [ ] **Step 2: Verify no Rails-specific term remains**

```bash
grep -inE "rails 8|rubocop|minitest|capybara|solid queue|solid cache|tailwind" common/CLAUDE.md
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add common/CLAUDE.md
git commit -m "feat(common): add language-neutral CLAUDE.md"
```

---

## Task 9: Move pipeline-reminder.txt into common/

**Files:**
- Move: `.claude/hooks/pipeline-reminder.txt` → `common/.claude/hooks/pipeline-reminder.txt`

- [ ] **Step 1: Create the destination directory**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p common/.claude/hooks
```

- [ ] **Step 2: Move the file**

```bash
git mv .claude/hooks/pipeline-reminder.txt common/.claude/hooks/pipeline-reminder.txt
git status
```

Expected: rename shown.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: move pipeline-reminder.txt into common"
```

---

## Task 10: Write the language-neutral common/.claude/settings.json

**Files:**
- Create: `common/.claude/settings.json`

- [ ] **Step 1: Write the file**

Write `/home/tonny/projects/00.base-files/common/.claude/settings.json` with content:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Glob|Grep",
        "hooks": [
          {
            "type": "command",
            "command": "[ -f graphify-out/graph.json ] && echo '{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"graphify: Knowledge graph exists. Read graphify-out/GRAPH_REPORT.md for god nodes and community structure before searching raw files.\"}}' || true"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "p=$(jq -r '.prompt'); if echo \"$p\" | grep -qiE '기능|구현|추가|만들|개발|feature|implement|build|develop'; then jq -n --rawfile ctx .claude/hooks/pipeline-reminder.txt '{hookSpecificOutput:{hookEventName:\"UserPromptSubmit\",additionalContext:$ctx}}'; fi",
            "timeout": 5,
            "statusMessage": "Checking pipeline phase..."
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

```bash
jq empty common/.claude/settings.json && echo "JSON OK"
```

Expected: `JSON OK`.

- [ ] **Step 3: Commit**

```bash
git add common/.claude/settings.json
git commit -m "feat(common): add language-neutral settings.json (graphify + pipeline hooks)"
```

---

## Task 11: Python overlay — STACK.md

**Files:**
- Create: `langs/python/docs/standards/STACK.md`

- [ ] **Step 1: Create directories**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p langs/python/docs/standards langs/python/.claude
```

- [ ] **Step 2: Write STACK.md**

Write `/home/tonny/projects/00.base-files/langs/python/docs/standards/STACK.md` with content:

````markdown
# Python Stack

> Installed by `install.sh` when a `pyproject.toml`, `requirements.txt`, or
> `Pipfile` was detected. To switch language overlay, re-run
> `install.sh --lang <other>`.

## Project Layout

```
.
├── pyproject.toml          # project metadata, dependencies, tool config
├── src/
│   └── <package>/__init__.py
├── tests/
│   └── conftest.py
└── README.md
```

Use the `src/` layout (not a flat top-level package). It prevents accidental
imports of in-tree modules during testing and surfaces missing-dependency
bugs before they reach production.

## Dependency Management

**Default: `uv`.** Reasons: lockfile-by-default, single tool for install +
run + venv, fast cold install.

```bash
uv init                  # one-time project init
uv add fastapi           # add a runtime dep
uv add --dev pytest ruff # add dev deps
uv sync                  # install from lock
uv run pytest            # run inside the venv without activation
```

Alternatives: `poetry` (acceptable when team standard), `pip-tools` (acceptable
for legacy projects). Avoid bare `pip install` without a lockfile.

Pin the Python version in `.python-version` (pyenv-compatible) or in
`pyproject.toml`'s `requires-python`.

## Framework Choice

| Workload                     | Recommended                        |
|------------------------------|------------------------------------|
| HTTP API, async-first        | FastAPI                            |
| HTTP API, sync-first         | Flask + Flask-Smorest, or Litestar |
| Full-stack with admin / ORM  | Django                             |
| CLI                          | Typer                              |
| Data pipeline / scheduling   | Prefect or Dagster                 |

For Django, use Django 5.x (LTS where available). For FastAPI, pin SQLAlchemy
2.x and use the new typed `Mapped` style. For async DB access, use
`asyncpg` or `databases`, not the sync DB-API in an async handler.

## Database & Migrations

- **ORM**: SQLAlchemy 2.x (preferred) or Django ORM. Avoid raw psycopg in app
  code; reserve raw SQL for migrations and ad-hoc scripts.
- **Migrations**: `alembic` (SQLAlchemy) or `django migrate` (Django). Never
  hand-edit a migration after it has been applied in any environment.
- **Connection pooling**: `asyncpg` has built-in pooling; SQLAlchemy uses
  `QueuePool` by default. Tune pool size to match worker concurrency.

## Background Jobs

| Need                          | Choice                                |
|-------------------------------|---------------------------------------|
| Simple async queue            | `arq` (Redis)                         |
| Mature task queue              | `dramatiq` (Redis or RabbitMQ)        |
| Legacy / Django integration   | `celery` + Redis                      |

Move slow third-party work (LLM, scraping, PDF generation) off the request
path. The user sees a polled or streamed status, never a blocked request.

## Caching

- **Process-local**: `functools.lru_cache` for pure functions
- **Cross-process**: Redis via `redis-py` async client
- Cache only what is both hot and slow (>50 ms recompute, data stable for at
  least one request). Always include a versioning key so stale entries clear
  on deploy.

## Security Specifics

- **CSRF**: Django ships CSRF middleware enabled by default; never disable it.
  FastAPI does not — wire `csrf-protect` middleware for non-API HTML routes.
- **Input validation**: Pydantic v2 for FastAPI request models; Django Forms
  for Django routes. Never trust `request.body` without parsing.
- **SQL injection**: always use the ORM or DB-API parameter placeholders
  (`%s`, never `f"... {value} ..."` in queries).
- **XSS**: Jinja2 and Django templates auto-escape by default — keep them on.
- **Secrets**: `pydantic-settings` reads from env / `.env` (gitignored) for
  local dev; production secrets come from the platform's secrets manager.
- **Rate limiting**: `slowapi` (FastAPI) or `django-ratelimit` for auth and
  public endpoints.

## Logging & Observability

- `structlog` for structured logs (JSON in production, human in dev)
- OpenTelemetry SDK for traces; export to whatever backend the platform
  provides
- Always log request_id / correlation_id; propagate across background-job
  boundaries

## Deployment

Containerize with a minimal Python base image (`python:3.12-slim` or
`gcr.io/distroless/python3`). Run with `uvicorn` (ASGI) or `gunicorn +
uvicorn workers`. Health endpoints (`/healthz`) return process status, not
DB status; readiness endpoints (`/readyz`) include DB / Redis reachability.

## Internationalization

- `babel` + gettext (`.po` files) for Django; `python-i18n` or
  `fluent.runtime` for FastAPI
- Source strings in English; translation files per locale under `locale/`
````

- [ ] **Step 3: Commit**

```bash
git add langs/python/docs/standards/STACK.md
git commit -m "feat(python): add STACK.md skeleton for Python overlay"
```

---

## Task 12: Python overlay — TOOLS.md

**Files:**
- Create: `langs/python/docs/standards/TOOLS.md`

- [ ] **Step 1: Write the file**

Write `/home/tonny/projects/00.base-files/langs/python/docs/standards/TOOLS.md` with content:

````markdown
# Python Toolchain

> Installed by `install.sh` when Python was detected. The pre-commit hooks in
> `.claude/settings.json` invoke these commands; keep them in sync with this
> document.

## Required

| Tool      | Purpose                                    | Install hint                                  |
|-----------|--------------------------------------------|-----------------------------------------------|
| `python`  | Runtime (≥ 3.11 recommended)               | `pyenv install 3.12` or system package        |
| `uv`      | Dependency manager + venv runner           | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `ruff`    | Linter + formatter                         | `uv add --dev ruff` (or `pipx install ruff`)  |
| `pytest`  | Test runner                                | `uv add --dev pytest`                         |

## Recommended

| Tool          | Purpose                                  |
|---------------|------------------------------------------|
| `mypy`        | Static type checking                     |
| `pip-audit`   | Dependency vulnerability scan            |
| `bandit`      | Static security scan                     |
| `pre-commit`  | Git-side hook framework (optional)       |

## Commands

### Tests

```bash
uv run pytest -q                     # full suite
uv run pytest -q tests/test_x.py     # one file
uv run pytest -q -k "test_name"      # by name
uv run pytest --lf                   # rerun last failures
```

The pre-commit hook runs `pytest -q` and denies the commit on non-zero exit.

### Linting & formatting

```bash
uv run ruff format .                 # apply formatting
uv run ruff check .                  # lint
uv run ruff check --fix .            # auto-fix safe issues
```

The pre-commit hook runs `ruff check .`; the `PostToolUse` hook on
`Write|Edit` runs `ruff format <file>` then `ruff check <file>` on the file
that was just modified.

### Type checking

```bash
uv run mypy src                       # strict mode is recommended
```

Add to CI; not in the pre-commit hook by default (too slow on large
codebases).

### Security

```bash
uv run pip-audit                      # dependency CVEs
uv run bandit -r src                  # source scan
```

### Database migrations

```bash
uv run alembic revision --autogenerate -m "<message>"
uv run alembic upgrade head
uv run alembic downgrade -1           # only in dev
```

(Replace with `manage.py migrate` for Django.)

### Running the app

```bash
uv run uvicorn app.main:app --reload  # FastAPI in dev
uv run python manage.py runserver     # Django in dev
```

## Pre-commit gate (enforced by `.claude/settings.json`)

1. `pytest -q` — timeout 120s
2. `ruff check .` — timeout 60s

Either failure denies the commit with the captured output. Fix locally and
retry. Never use `git commit --no-verify`.
````

- [ ] **Step 2: Commit**

```bash
git add langs/python/docs/standards/TOOLS.md
git commit -m "feat(python): add TOOLS.md for Python overlay"
```

---

## Task 13: Python overlay — settings.json

**Files:**
- Create: `langs/python/.claude/settings.json`

- [ ] **Step 1: Write the file**

Write `/home/tonny/projects/00.base-files/langs/python/.claude/settings.json` with content:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": "if command -v uv >/dev/null && [ -f pyproject.toml ]; then uv run pytest -q > /tmp/pytest_output.txt 2>&1; rc=$?; else pytest -q > /tmp/pytest_output.txt 2>&1; rc=$?; fi; if [ $rc -ne 0 ]; then jq -n --rawfile out /tmp/pytest_output.txt '{hookSpecificOutput:{hookEventName:\"PreToolUse\",permissionDecision:\"deny\",permissionDecisionReason:(\"pytest failed. Diagnose the failures, fix the code, and retry the commit.\\n\\n--- pytest -q output ---\\n\" + $out)}}'; fi",
            "timeout": 120,
            "statusMessage": "Running pytest before commit..."
          },
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": "if command -v uv >/dev/null && [ -f pyproject.toml ]; then uv run ruff check . > /tmp/ruff_output.txt 2>&1; rc=$?; else ruff check . > /tmp/ruff_output.txt 2>&1; rc=$?; fi; if [ $rc -ne 0 ]; then jq -n --rawfile out /tmp/ruff_output.txt '{hookSpecificOutput:{hookEventName:\"PreToolUse\",permissionDecision:\"deny\",permissionDecisionReason:(\"Ruff violations found. Run `ruff check --fix .` then `ruff format .`, re-stage, and retry.\\n\\n--- ruff check output ---\\n\" + $out)}}'; fi",
            "timeout": 60,
            "statusMessage": "Running ruff before commit..."
          }
        ]
      }
    ],
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

- [ ] **Step 2: Validate JSON**

```bash
jq empty langs/python/.claude/settings.json && echo "JSON OK"
```

Expected: `JSON OK`.

- [ ] **Step 3: Commit**

```bash
git add langs/python/.claude/settings.json
git commit -m "feat(python): add Python-specific pre-commit and PostToolUse hooks"
```

---

## Task 14: Go overlay — STACK.md

**Files:**
- Create: `langs/go/docs/standards/STACK.md`

- [ ] **Step 1: Create directories**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p langs/go/docs/standards langs/go/.claude
```

- [ ] **Step 2: Write the file**

Write `/home/tonny/projects/00.base-files/langs/go/docs/standards/STACK.md` with content:

````markdown
# Go Stack

> Installed by `install.sh` when a `go.mod` was detected. To switch language
> overlay, re-run `install.sh --lang <other>`.

## Project Layout

Use the [standard Go project layout](https://github.com/golang-standards/project-layout)
selectively — pull in only the directories you need:

```
.
├── go.mod
├── go.sum
├── cmd/<app>/main.go            # one main per executable
├── internal/                    # not importable from outside this module
│   ├── <domain>/
│   └── platform/                # logging, config, db wiring
├── pkg/                         # reusable libraries (only if you publish)
└── api/openapi.yaml             # if HTTP API
```

Avoid `pkg/` unless you actually publish a library. Default to `internal/`.

## Module Management

```bash
go mod init github.com/<org>/<repo>
go get example.com/lib@latest
go mod tidy
```

Vendor only when offline-build or reproducibility regulations require it.

## HTTP / Framework Choice

| Workload                         | Recommended                                 |
|----------------------------------|---------------------------------------------|
| Lightweight HTTP API             | `net/http` + `chi` (router)                 |
| Faster prototyping               | `echo` or `fiber`                            |
| Full-feature framework           | `gin` (most middleware)                      |
| gRPC                              | `google.golang.org/grpc`                     |
| CLI                              | `cobra` + `viper`                            |

Prefer the standard library where it suffices. Reach for a framework only
when middleware demand passes a clear threshold.

## Database & Migrations

- **Driver**: `database/sql` + `pgx/v5/stdlib` for Postgres, or `pgx/v5` async
  pool directly
- **ORM-lite**: `sqlc` (codegen from SQL) for type-safe queries; `gorm` is
  acceptable but discouraged for new code
- **Migrations**: `golang-migrate/migrate` or `pressly/goose`. Never hand-edit
  an applied migration; create a new one.
- **Connection pooling**: `pgxpool` for direct pgx; `database/sql` pool tuned
  via `SetMaxOpenConns`

## Concurrency Patterns

- Goroutines + channels for fan-out / fan-in
- `context.Context` is the first parameter of every function that performs
  I/O — propagate cancellation; never ignore it
- `errgroup.WithContext` for parallel work that should cancel on any error
- Avoid `sync.Mutex` when a channel suffices; reach for the mutex when
  state must be read by many goroutines

## Background Jobs

| Need                                  | Choice                              |
|---------------------------------------|-------------------------------------|
| In-process worker (single-binary)     | goroutines + channels + ticker      |
| Out-of-process queue                  | `hibiken/asynq` (Redis)             |
| Cron                                  | `robfig/cron/v3`                    |

## Caching

- In-process: `golang-lru/v2` for bounded LRU; `sync.Map` for hot lookups
- Distributed: Redis via `redis/go-redis/v9`

## Security Specifics

- **Input validation**: `go-playground/validator/v10` for HTTP request structs
- **SQL injection**: always parameterized queries (`$1`, `$2`); never
  `fmt.Sprintf` into SQL
- **XSS**: `html/template` auto-escapes; `text/template` does NOT — use the
  right one for HTML output
- **CSRF**: `gorilla/csrf` middleware for HTML form routes; for JSON APIs
  prefer `SameSite=Strict` cookies and short-lived bearer tokens
- **Secrets**: env vars in dev; platform secrets manager in prod; do not
  commit `.env`
- **Rate limiting**: `golang.org/x/time/rate` token-bucket; wrap auth and
  public endpoints

## Logging & Observability

- `log/slog` (stdlib) for structured logs — JSON handler in production
- OpenTelemetry via `go.opentelemetry.io/otel` for traces
- Propagate request_id / trace_id through `context.Context`

## Deployment

Static binary, scratch / distroless base image. Health endpoint returns 200
when the process is alive; readiness endpoint includes DB/Redis pings.

## Internationalization

- `golang.org/x/text/language` + `message` for catalogs
- Source strings in English; per-locale `.go` catalogs generated by `gotext`
````

- [ ] **Step 3: Commit**

```bash
git add langs/go/docs/standards/STACK.md
git commit -m "feat(go): add STACK.md skeleton for Go overlay"
```

---

## Task 15: Go overlay — TOOLS.md

**Files:**
- Create: `langs/go/docs/standards/TOOLS.md`

- [ ] **Step 1: Write the file**

Write `/home/tonny/projects/00.base-files/langs/go/docs/standards/TOOLS.md` with content:

````markdown
# Go Toolchain

> Installed by `install.sh` when Go was detected. The pre-commit hooks in
> `.claude/settings.json` invoke these commands; keep them in sync with this
> document.

## Required

| Tool             | Purpose                                | Install hint                                                |
|------------------|----------------------------------------|-------------------------------------------------------------|
| `go`             | Runtime + build tool (≥ 1.22)          | `brew install go` or system package                          |
| `gofmt`          | Formatter (ships with `go`)            | bundled                                                      |
| `go vet`         | Built-in static analysis               | bundled                                                      |
| `golangci-lint`  | Aggregate linter                       | `brew install golangci-lint` or `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` |

## Recommended

| Tool             | Purpose                            |
|------------------|------------------------------------|
| `staticcheck`    | Deeper SA (subset of golangci-lint) |
| `govulncheck`    | Vulnerability scan                  |
| `delve`          | Debugger                            |
| `air`            | Live reload during dev              |

## Commands

### Tests

```bash
go test ./...                      # full suite
go test ./pkg/foo -run TestBar     # one test
go test -race ./...                # race detector (run in CI)
go test -cover ./...               # coverage summary
```

The pre-commit hook runs `go test ./...` and denies the commit on non-zero
exit.

### Formatting

```bash
gofmt -w .                          # apply formatting in place
goimports -w .                      # gofmt + manage imports (if installed)
```

`PostToolUse` runs `gofmt -w <file>` on the file that was just edited.

### Linting

```bash
go vet ./...                        # built-in
golangci-lint run                   # aggregate
golangci-lint run --fix             # auto-fix where supported
```

The pre-commit hook runs `golangci-lint run`.

### Security

```bash
govulncheck ./...                   # known CVEs in dependencies + stdlib
```

### Build

```bash
go build -trimpath -ldflags "-s -w" -o ./bin/<app> ./cmd/<app>
```

### Database migrations

```bash
migrate -path ./migrations -database "$DATABASE_URL" up
migrate -path ./migrations -database "$DATABASE_URL" down 1
```

(Replace with `goose -dir ./migrations <db> up` if using `pressly/goose`.)

### Running the app (dev)

```bash
go run ./cmd/<app>
air                                 # if Air is installed for live reload
```

## Pre-commit gate (enforced by `.claude/settings.json`)

1. `go test ./...` — timeout 180s
2. `golangci-lint run` — timeout 90s

Either failure denies the commit with the captured output. Fix locally and
retry. Never use `git commit --no-verify`.
````

- [ ] **Step 2: Commit**

```bash
git add langs/go/docs/standards/TOOLS.md
git commit -m "feat(go): add TOOLS.md for Go overlay"
```

---

## Task 16: Go overlay — settings.json

**Files:**
- Create: `langs/go/.claude/settings.json`

- [ ] **Step 1: Write the file**

Write `/home/tonny/projects/00.base-files/langs/go/.claude/settings.json` with content:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": "if command -v go >/dev/null && [ -f go.mod ]; then go test ./... > /tmp/gotest_output.txt 2>&1; rc=$?; if [ $rc -ne 0 ]; then jq -n --rawfile out /tmp/gotest_output.txt '{hookSpecificOutput:{hookEventName:\"PreToolUse\",permissionDecision:\"deny\",permissionDecisionReason:(\"go test failed. Diagnose and fix before retrying the commit.\\n\\n--- go test ./... output ---\\n\" + $out)}}'; fi; fi",
            "timeout": 180,
            "statusMessage": "Running go test before commit..."
          },
          {
            "type": "command",
            "if": "Bash(git commit*)",
            "command": "if command -v golangci-lint >/dev/null && [ -f go.mod ]; then golangci-lint run > /tmp/golint_output.txt 2>&1; rc=$?; if [ $rc -ne 0 ]; then jq -n --rawfile out /tmp/golint_output.txt '{hookSpecificOutput:{hookEventName:\"PreToolUse\",permissionDecision:\"deny\",permissionDecisionReason:(\"golangci-lint violations found. Run `golangci-lint run --fix`, re-stage, retry.\\n\\n--- golangci-lint run output ---\\n\" + $out)}}'; fi; fi",
            "timeout": 90,
            "statusMessage": "Running golangci-lint before commit..."
          }
        ]
      }
    ],
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

- [ ] **Step 2: Validate JSON**

```bash
jq empty langs/go/.claude/settings.json && echo "JSON OK"
```

Expected: `JSON OK`.

- [ ] **Step 3: Commit**

```bash
git add langs/go/.claude/settings.json
git commit -m "feat(go): add Go-specific pre-commit and PostToolUse hooks"
```

---

## Task 17: lib/log.sh

**Files:**
- Create: `lib/log.sh`
- Create: `tests/test_log.sh`

- [ ] **Step 1: Create directories**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p lib tests
```

- [ ] **Step 2: Write the failing test**

Write `/home/tonny/projects/00.base-files/tests/test_log.sh`:

```bash
#!/usr/bin/env bash
# Test: lib/log.sh emits expected prefixes and respects NO_COLOR.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# Capture stdout/stderr and verify each helper prefixes its output.
out="$(log_info "hello" 2>&1)"
[[ "$out" == *"[INFO]"*"hello"* ]] || fail "log_info missing [INFO] prefix: $out"
ok "log_info"

out="$(log_ok "fine" 2>&1)"
[[ "$out" == *"[OK]"*"fine"* ]] || fail "log_ok missing [OK] prefix: $out"
ok "log_ok"

out="$(log_warn "careful" 2>&1)"
[[ "$out" == *"[WARN]"*"careful"* ]] || fail "log_warn missing [WARN] prefix: $out"
ok "log_warn"

out="$(log_error "boom" 2>&1)"
[[ "$out" == *"[ERROR]"*"boom"* ]] || fail "log_error missing [ERROR] prefix: $out"
ok "log_error"

out="$(log_action "doing" 2>&1)"
[[ "$out" == *"[*]"*"doing"* ]] || fail "log_action missing [*] prefix: $out"
ok "log_action"

out="$(log_section "Phase 1" 2>&1)"
[[ "$out" == *"Phase 1"* ]] || fail "log_section missing label: $out"
ok "log_section"

# NO_COLOR: when set, no ANSI escapes should appear.
out="$(NO_COLOR=1 log_info "plain" 2>&1)"
[[ "$out" != *$'\e['* ]] || fail "NO_COLOR did not suppress ANSI escapes"
ok "NO_COLOR honored"

echo "test_log.sh: ALL PASS"
```

```bash
chmod +x tests/test_log.sh
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_log.sh
```

Expected: failure (either `lib/log.sh: No such file or directory` from `source`, or shell aborts).

- [ ] **Step 4: Write `lib/log.sh`**

Write `/home/tonny/projects/00.base-files/lib/log.sh`:

```bash
# lib/log.sh — color logger for install.sh and lib/* modules.
# Source this file; do not execute it directly.

# Respect NO_COLOR (https://no-color.org/) and the absence of a TTY.
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
  _LOG_C_RESET=""
  _LOG_C_INFO=""
  _LOG_C_OK=""
  _LOG_C_WARN=""
  _LOG_C_ERROR=""
  _LOG_C_ACTION=""
  _LOG_C_SECTION=""
else
  _LOG_C_RESET=$'\e[0m'
  _LOG_C_INFO=$'\e[36m'        # cyan
  _LOG_C_OK=$'\e[32m'          # green
  _LOG_C_WARN=$'\e[33m'        # yellow
  _LOG_C_ERROR=$'\e[31m'       # red
  _LOG_C_ACTION=$'\e[35m'      # magenta
  _LOG_C_SECTION=$'\e[1;34m'   # bold blue
fi

log_info()    { printf '%s[INFO]%s %s\n'    "$_LOG_C_INFO"    "$_LOG_C_RESET" "$*"; }
log_ok()      { printf '%s[OK]%s %s\n'      "$_LOG_C_OK"      "$_LOG_C_RESET" "$*"; }
log_warn()    { printf '%s[WARN]%s %s\n'    "$_LOG_C_WARN"    "$_LOG_C_RESET" "$*" >&2; }
log_error()   { printf '%s[ERROR]%s %s\n'   "$_LOG_C_ERROR"   "$_LOG_C_RESET" "$*" >&2; }
log_action()  { printf '%s[*]%s %s\n'       "$_LOG_C_ACTION"  "$_LOG_C_RESET" "$*"; }
log_section() {
  local label="$*"
  printf '\n%s== %s ==%s\n' "$_LOG_C_SECTION" "$label" "$_LOG_C_RESET"
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_log.sh
```

Expected: `test_log.sh: ALL PASS` as final line; exit code 0.

- [ ] **Step 6: Commit**

```bash
git add lib/log.sh tests/test_log.sh
git commit -m "feat(lib): add log.sh color helpers with NO_COLOR support"
```

---

## Task 18: lib/detect-language.sh

**Files:**
- Create: `lib/detect-language.sh`
- Create: `tests/test_detect_language.sh`

- [ ] **Step 1: Write the failing test**

Write `/home/tonny/projects/00.base-files/tests/test_detect_language.sh`:

```bash
#!/usr/bin/env bash
# Test: detect_language returns rails/python/go from the right manifest files,
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

# Case 8: invalid override exits non-zero
set +e
( cd "$TMP/rails-proj" && detect_language "nodejs" ) >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "invalid override should exit non-zero (got $rc)"
ok "invalid override rejected"

# Case 9: ambiguous (no manifest, no override) -> non-zero AND prints hint to stderr
mkdir "$TMP/empty-proj"
set +e
err=$( ( cd "$TMP/empty-proj" && BASE_FILES_NONINTERACTIVE=1 detect_language "" ) 2>&1 1>/dev/null )
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "ambiguous in non-interactive mode should exit non-zero"
[[ "$err" == *"--lang"* ]] || fail "ambiguous error should mention --lang (got: $err)"
ok "ambiguous in non-interactive mode rejected"

echo "test_detect_language.sh: ALL PASS"
```

```bash
chmod +x tests/test_detect_language.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_detect_language.sh
```

Expected: failure on the first `source` call (file does not exist yet).

- [ ] **Step 3: Write `lib/detect-language.sh`**

Write `/home/tonny/projects/00.base-files/lib/detect-language.sh`:

```bash
# lib/detect-language.sh — choose one language overlay for a target directory.
# Usage (sourced): detect_language [<override>]
# Prints rails|python|go to stdout, hints to stderr.

_BASE_FILES_LANGS=(rails python go)

_is_valid_lang() {
  local candidate="$1"
  for l in "${_BASE_FILES_LANGS[@]}"; do
    [[ "$l" == "$candidate" ]] && return 0
  done
  return 1
}

detect_language() {
  local override="${1:-}"

  if [[ -n "$override" ]]; then
    if _is_valid_lang "$override"; then
      printf '%s\n' "$override"
      return 0
    fi
    log_error "unknown --lang value: '$override' (allowed: ${_BASE_FILES_LANGS[*]})"
    return 2
  fi

  # Manifest sniffing in the current working directory.
  if [[ -f Gemfile ]] || compgen -G "*.gemspec" >/dev/null 2>&1; then
    printf 'rails\n'; return 0
  fi
  if [[ -f pyproject.toml || -f requirements.txt || -f Pipfile ]]; then
    printf 'python\n'; return 0
  fi
  if [[ -f go.mod ]]; then
    printf 'go\n'; return 0
  fi

  # Ambiguous: interactive prompt unless suppressed.
  if [[ "${BASE_FILES_NONINTERACTIVE:-0}" == "1" ]]; then
    log_error "no manifest detected and BASE_FILES_NONINTERACTIVE=1; re-run with --lang <rails|python|go>"
    return 3
  fi

  log_warn "no language manifest detected in $(pwd)" >&2
  printf 'Select language: ' >&2
  local choice
  select choice in "${_BASE_FILES_LANGS[@]}"; do
    if [[ -n "${choice:-}" ]]; then
      printf '%s\n' "$choice"
      return 0
    fi
  done < /dev/tty
  log_error "no selection made"
  return 3
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_detect_language.sh
```

Expected: every `ok:` line, then `test_detect_language.sh: ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/detect-language.sh tests/test_detect_language.sh
git commit -m "feat(lib): add detect-language.sh with manifest sniffing + override"
```

---

## Task 19: lib/check-deps.sh

**Files:**
- Create: `lib/check-deps.sh`
- Create: `tests/test_check_deps.sh`

- [ ] **Step 1: Write the failing test**

Write `/home/tonny/projects/00.base-files/tests/test_check_deps.sh`:

```bash
#!/usr/bin/env bash
# Test: check_deps returns 0 when required tools exist; marks missing ones
# in MISSING_DEPS array; never errors on absence.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=../lib/check-deps.sh
source "$ROOT/lib/check-deps.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# Case 1: with `jq`, `git` present (assume they are) — MISSING_DEPS does not include them.
MISSING_DEPS=()
check_deps rails >/dev/null 2>&1 || true
for t in jq git; do
  for m in "${MISSING_DEPS[@]:-}"; do
    [[ "$m" == "$t" ]] && fail "$t reported missing but should be present"
  done
done
ok "real deps not falsely reported missing"

# Case 2: spoof a missing tool by shadowing PATH so a fake required tool name vanishes.
# We can't easily spoof "ruby is missing" without uninstalling — instead inject a fake
# required dep into a copy of the function via a wrapper.
test_missing_wrapper() {
  MISSING_DEPS=()
  REQUIRED_OS=(definitelynotinpath_xyz)
  REQUIRED_LANG_rails=()
  check_deps rails >/dev/null 2>&1 || true
  local found=0
  for m in "${MISSING_DEPS[@]:-}"; do
    [[ "$m" == "definitelynotinpath_xyz" ]] && found=1
  done
  [[ $found -eq 1 ]] || fail "missing tool not recorded in MISSING_DEPS"
}
test_missing_wrapper
ok "missing tool reported in MISSING_DEPS"

echo "test_check_deps.sh: ALL PASS"
```

```bash
chmod +x tests/test_check_deps.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_check_deps.sh
```

Expected: failure on `source` (file missing).

- [ ] **Step 3: Write `lib/check-deps.sh`**

Write `/home/tonny/projects/00.base-files/lib/check-deps.sh`:

```bash
# lib/check-deps.sh — verify presence of required CLI tools.
# Usage (sourced): check_deps <language>
# Populates the array MISSING_DEPS with missing tool names; never exits.

# Override-able lists. Defaults are sensible; tests can override before calling.
: "${REQUIRED_OS:=}"
if [[ -z "${REQUIRED_OS:-}" ]]; then
  REQUIRED_OS=(jq git)
fi

: "${REQUIRED_LANG_rails:=}"; [[ -z "${REQUIRED_LANG_rails:-}" ]] && REQUIRED_LANG_rails=(ruby)
: "${REQUIRED_LANG_python:=}"; [[ -z "${REQUIRED_LANG_python:-}" ]] && REQUIRED_LANG_python=(python3)
: "${REQUIRED_LANG_go:=}"; [[ -z "${REQUIRED_LANG_go:-}" ]] && REQUIRED_LANG_go=(go)

_install_hint() {
  case "$1" in
    jq)      echo "sudo apt install -y jq        # or: brew install jq" ;;
    git)     echo "sudo apt install -y git       # or: brew install git" ;;
    gh)      echo "sudo apt install -y gh        # or: brew install gh" ;;
    ruby)    echo "brew install rbenv && rbenv install 3.3.0  # or use system package" ;;
    python3) echo "brew install pyenv && pyenv install 3.12   # or use system package" ;;
    go)      echo "brew install go               # or use system package" ;;
    claude)  echo "see https://docs.claude.com/claude-code for the install script" ;;
    *)       echo "install '$1' via your package manager" ;;
  esac
}

check_deps() {
  local lang="${1:-}"
  MISSING_DEPS=()

  local all=()
  for t in "${REQUIRED_OS[@]}"; do all+=("$t"); done
  case "$lang" in
    rails)  for t in "${REQUIRED_LANG_rails[@]}";  do all+=("$t"); done ;;
    python) for t in "${REQUIRED_LANG_python[@]}"; do all+=("$t"); done ;;
    go)     for t in "${REQUIRED_LANG_go[@]}";     do all+=("$t"); done ;;
  esac

  for t in "${all[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      log_ok "$t found"
    else
      MISSING_DEPS+=("$t")
      log_warn "$t missing — install with: $(_install_hint "$t")"
    fi
  done

  return 0
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_check_deps.sh
```

Expected: `test_check_deps.sh: ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/check-deps.sh tests/test_check_deps.sh
git commit -m "feat(lib): add check-deps.sh (report-only OS dependency probe)"
```

---

## Task 20: lib/copy-files.sh

**Files:**
- Create: `lib/copy-files.sh`
- Create: `tests/test_copy_files.sh`

- [ ] **Step 1: Write the failing test**

Write `/home/tonny/projects/00.base-files/tests/test_copy_files.sh`:

```bash
#!/usr/bin/env bash
# Test: copy_files merges common/ and langs/<lang>/ into a target dir, backs
# up existing files with a timestamp suffix, and respects --force semantics.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"
# shellcheck source=../lib/copy-files.sh
source "$ROOT/lib/copy-files.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build a fake common/ and rails/
mkdir -p "$TMP/src/common/docs/standards" "$TMP/src/langs/rails/docs/standards"
echo "common-rules" > "$TMP/src/common/docs/standards/RULES.md"
echo "rails-stack"  > "$TMP/src/langs/rails/docs/standards/STACK.md"

# Case 1: copy into empty target
mkdir "$TMP/dst1"
copy_files "$TMP/src/common" "$TMP/src/langs/rails" "$TMP/dst1" 1 0  # force=1, dry=0
[[ -f "$TMP/dst1/docs/standards/RULES.md" ]] || fail "RULES.md not copied"
[[ -f "$TMP/dst1/docs/standards/STACK.md" ]] || fail "STACK.md not copied"
ok "fresh copy"

# Case 2: copy into target with conflict; force=1 should back up existing
mkdir -p "$TMP/dst2/docs/standards"
echo "old-rules" > "$TMP/dst2/docs/standards/RULES.md"
copy_files "$TMP/src/common" "$TMP/src/langs/rails" "$TMP/dst2" 1 0
[[ -f "$TMP/dst2/docs/standards/RULES.md" ]] || fail "RULES.md not present after overwrite"
grep -q "common-rules" "$TMP/dst2/docs/standards/RULES.md" || fail "RULES.md not overwritten"
ls "$TMP/dst2/docs/standards/" | grep -E "RULES.md.bak.[0-9]" >/dev/null || fail "no backup file created"
ok "conflict overwrites with backup"

# Case 3: dry run does not write anything
mkdir "$TMP/dst3"
copy_files "$TMP/src/common" "$TMP/src/langs/rails" "$TMP/dst3" 1 1  # force=1, dry=1
[[ ! -f "$TMP/dst3/docs/standards/RULES.md" ]] || fail "dry-run wrote a file"
ok "dry-run is read-only"

echo "test_copy_files.sh: ALL PASS"
```

```bash
chmod +x tests/test_copy_files.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_copy_files.sh
```

Expected: failure on `source`.

- [ ] **Step 3: Write `lib/copy-files.sh`**

Write `/home/tonny/projects/00.base-files/lib/copy-files.sh`:

```bash
# lib/copy-files.sh — copy common/ and langs/<lang>/ trees into a target dir.
# Usage (sourced): copy_files <common_src> <lang_src> <dst> <force:0|1> <dry:0|1>
# Skips .claude/settings.json (handled by merge_settings).

_backup_suffix() { date +".bak.%Y%m%d-%H%M%S"; }

_copy_one() {
  # _copy_one <src_file> <dst_file> <force> <dry>
  local src="$1" dst="$2" force="$3" dry="$4"

  # Skip settings.json — merge_settings handles it.
  if [[ "$(basename "$dst")" == "settings.json" && "$(dirname "$dst")" == *".claude" ]]; then
    return 0
  fi

  if [[ -e "$dst" ]]; then
    if [[ "$force" -eq 1 ]]; then
      local bak; bak="${dst}$(_backup_suffix)"
      if [[ "$dry" -eq 1 ]]; then
        log_action "(dry-run) would back up $dst -> $bak"
      else
        mv "$dst" "$bak"
        log_action "backed up $dst -> $bak"
      fi
    else
      printf 'File exists: %s\n  [o]verwrite (with backup) / [s]kip / [q]uit ? ' "$dst" >&2
      local ans; read -r ans </dev/tty
      case "${ans:-}" in
        o|O)
          local bak; bak="${dst}$(_backup_suffix)"
          if [[ "$dry" -eq 1 ]]; then
            log_action "(dry-run) would back up $dst -> $bak"
          else
            mv "$dst" "$bak"
            log_action "backed up $dst -> $bak"
          fi
          ;;
        s|S) log_info "skipping $dst"; return 0 ;;
        *)   log_error "aborting on user request"; return 4 ;;
      esac
    fi
  fi

  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would copy $src -> $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log_ok "copied $src -> $dst"
  fi
}

_walk_and_copy() {
  # _walk_and_copy <src_root> <dst_root> <force> <dry>
  local src="$1" dst="$2" force="$3" dry="$4"
  [[ -d "$src" ]] || return 0
  local rel
  while IFS= read -r -d '' f; do
    rel="${f#"$src/"}"
    _copy_one "$f" "$dst/$rel" "$force" "$dry" || return $?
  done < <(find "$src" -type f -print0)
}

copy_files() {
  local common_src="$1" lang_src="$2" dst="$3" force="$4" dry="$5"
  _walk_and_copy "$common_src" "$dst" "$force" "$dry" || return $?
  _walk_and_copy "$lang_src"   "$dst" "$force" "$dry" || return $?
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_copy_files.sh
```

Expected: `test_copy_files.sh: ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/copy-files.sh tests/test_copy_files.sh
git commit -m "feat(lib): add copy-files.sh with backup + dry-run support"
```

---

## Task 21: lib/merge-settings.sh

**Files:**
- Create: `lib/merge-settings.sh`
- Create: `tests/test_merge_settings.sh`

- [ ] **Step 1: Write the failing test**

Write `/home/tonny/projects/00.base-files/tests/test_merge_settings.sh`:

```bash
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
```

```bash
chmod +x tests/test_merge_settings.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_merge_settings.sh
```

Expected: failure on `source`.

- [ ] **Step 3: Write `lib/merge-settings.sh`**

Write `/home/tonny/projects/00.base-files/lib/merge-settings.sh`:

```bash
# lib/merge-settings.sh — deep-merge two Claude Code settings.json files.
# Usage (sourced): merge_settings <common.json> <lang.json> <target.json> <dry:0|1>
# Concatenates arrays under .hooks.PreToolUse / PostToolUse / UserPromptSubmit.
# Validates the result with `jq empty`. Atomic write on success.

merge_settings() {
  local common="$1" lang="$2" target="$3" dry="$4"

  [[ -f "$common" ]] || { log_error "missing common settings: $common"; return 5; }
  [[ -f "$lang"   ]] || { log_error "missing lang settings: $lang";     return 5; }

  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would merge $common + $lang -> $target"
    return 0
  fi

  local tmp; tmp="$(mktemp)"
  if ! jq -s '
    reduce .[] as $x (
      {hooks:{}};
      .hooks.PreToolUse       = ((.hooks.PreToolUse       // []) + ($x.hooks.PreToolUse       // [])) |
      .hooks.PostToolUse      = ((.hooks.PostToolUse      // []) + ($x.hooks.PostToolUse      // [])) |
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + ($x.hooks.UserPromptSubmit // []))
    )
  ' "$common" "$lang" > "$tmp"; then
    log_error "jq merge failed"
    rm -f "$tmp"
    return 6
  fi

  if ! jq empty "$tmp" >/dev/null 2>&1; then
    log_error "merged settings.json is invalid JSON"
    rm -f "$tmp"
    return 7
  fi

  mkdir -p "$(dirname "$target")"
  mv "$tmp" "$target"
  log_ok "merged settings.json -> $target"
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_merge_settings.sh
```

Expected: `test_merge_settings.sh: ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/merge-settings.sh tests/test_merge_settings.sh
git commit -m "feat(lib): add merge-settings.sh (jq deep-merge with validation)"
```

---

## Task 22: lib/install-skills.sh

**Files:**
- Create: `lib/install-skills.sh`
- Create: `tests/test_install_skills.sh`

This module shells out to the real `claude` CLI; the test mocks it via a fake on PATH so the test is hermetic.

- [ ] **Step 1: Write the failing test**

Write `/home/tonny/projects/00.base-files/tests/test_install_skills.sh`:

```bash
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
case "$1 $2 $3" in
  "plugin marketplace list") printf '%s\n' ${CLAUDE_FAKE_MARKETPLACES:-}; exit 0 ;;
  "plugin list")             printf '%s\n' ${CLAUDE_FAKE_PLUGINS:-};      exit 0 ;;
esac
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
```

```bash
chmod +x tests/test_install_skills.sh
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_install_skills.sh
```

Expected: failure on `source`.

- [ ] **Step 3: Write `lib/install-skills.sh`**

Write `/home/tonny/projects/00.base-files/lib/install-skills.sh`:

```bash
# lib/install-skills.sh — install recommended Claude Code plugins.
# Usage (sourced): install_skills <dry:0|1>
# Idempotent: skips marketplaces and plugins that are already present.

_TARGET_MARKETPLACES=(
  "claude-plugins-official|anthropics/claude-plugins-official"
  "karpathy-skills|forrestchang/andrej-karpathy-skills"
)

_TARGET_PLUGINS=(
  "superpowers@claude-plugins-official"
  "code-review@claude-plugins-official"
  "andrej-karpathy-skills@karpathy-skills"
)

_ensure_marketplace() {
  # _ensure_marketplace <name> <repo> <dry>
  local name="$1" repo="$2" dry="$3"
  if claude plugin marketplace list 2>/dev/null | grep -q "^${name}\b"; then
    log_info "marketplace already added: ${name}"
    return 0
  fi
  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would add marketplace ${name} (${repo})"
    return 0
  fi
  log_action "adding marketplace ${name} (${repo})"
  claude plugin marketplace add "$repo" || log_warn "marketplace add failed: ${name}"
}

_ensure_plugin() {
  # _ensure_plugin <plugin@marketplace> <dry>
  local spec="$1" dry="$2"
  if claude plugin list 2>/dev/null | grep -q "${spec}"; then
    log_info "plugin already installed: ${spec}"
    return 0
  fi
  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would install ${spec}"
    return 0
  fi
  log_action "installing plugin ${spec}"
  claude plugin install "$spec" || log_warn "plugin install failed: ${spec}"
}

install_skills() {
  local dry="${1:-0}"

  if ! command -v claude >/dev/null 2>&1; then
    log_warn "claude CLI not found; skipping plugin installation. See https://docs.claude.com/claude-code"
    return 0
  fi

  for entry in "${_TARGET_MARKETPLACES[@]}"; do
    local name="${entry%%|*}" repo="${entry#*|}"
    _ensure_marketplace "$name" "$repo" "$dry"
  done

  for spec in "${_TARGET_PLUGINS[@]}"; do
    _ensure_plugin "$spec" "$dry"
  done

  if [[ -d "${HOME}/.claude/skills/graphify" ]]; then
    log_ok "graphify skill detected at ~/.claude/skills/graphify"
  else
    log_warn "graphify skill not found at ~/.claude/skills/graphify; install manually if you want it"
  fi
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /home/tonny/projects/00.base-files
./tests/test_install_skills.sh
```

Expected: `test_install_skills.sh: ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/install-skills.sh tests/test_install_skills.sh
git commit -m "feat(lib): add install-skills.sh (idempotent claude plugin orchestration)"
```

---

## Task 23: install.sh entry point

**Files:**
- Create: `install.sh`
- Modify (delete): `CLAUDE.md`, `.claude/settings.json`, `.claude/hooks/` (empty dir cleanup)

- [ ] **Step 1: Write `install.sh`**

Write `/home/tonny/projects/00.base-files/install.sh`:

```bash
#!/usr/bin/env bash
# install.sh — bootstrap a new project from base-files.
# Run from inside the target project directory:
#   ~/projects/00.base-files/install.sh [--lang rails|python|go] [--dry-run] [--force] [--skip-skills]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect-language.sh
source "$SCRIPT_DIR/lib/detect-language.sh"
# shellcheck source=lib/check-deps.sh
source "$SCRIPT_DIR/lib/check-deps.sh"
# shellcheck source=lib/copy-files.sh
source "$SCRIPT_DIR/lib/copy-files.sh"
# shellcheck source=lib/merge-settings.sh
source "$SCRIPT_DIR/lib/merge-settings.sh"
# shellcheck source=lib/install-skills.sh
source "$SCRIPT_DIR/lib/install-skills.sh"

usage() {
  cat <<EOF
Usage: install.sh [options]

Run from inside the new project's directory. Detects language from manifest
files, copies the common core + one language overlay, merges hook settings,
and installs recommended Claude Code plugins.

Options:
  --lang <rails|python|go>   Override language auto-detection
  --dry-run                  Print the plan without writing files or invoking claude
  --force                    Overwrite existing files (always with timestamped backup)
  --skip-skills              Skip plugin installation entirely
  -h, --help                 Show this help

Examples:
  cd ~/projects/my-rails-app && ~/projects/00.base-files/install.sh
  cd ~/projects/my-py-app && ~/projects/00.base-files/install.sh --lang python --force
EOF
}

LANG_OVERRIDE=""
DRY_RUN=0
FORCE=0
SKIP_SKILLS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)        LANG_OVERRIDE="${2:-}"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --force)       FORCE=1; shift ;;
    --skip-skills) SKIP_SKILLS=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             log_error "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

TARGET="$(pwd)"
log_section "Bootstrapping $(basename "$TARGET")"
log_info "source:  $SCRIPT_DIR"
log_info "target:  $TARGET"
[[ "$DRY_RUN"     -eq 1 ]] && log_warn "DRY-RUN mode — no changes will be written"
[[ "$FORCE"       -eq 1 ]] && log_warn "FORCE mode — existing files will be overwritten (backed up)"
[[ "$SKIP_SKILLS" -eq 1 ]] && log_warn "SKIP-SKILLS mode — plugin installation suppressed"

log_section "1/5  Detecting language"
DETECTED_LANG="$(detect_language "$LANG_OVERRIDE")" || exit $?
log_ok "language: $DETECTED_LANG"

log_section "2/5  Checking OS dependencies"
check_deps "$DETECTED_LANG"
MISSING_COUNT="${#MISSING_DEPS[@]}"

log_section "3/5  Copying common + $DETECTED_LANG files"
copy_files \
  "$SCRIPT_DIR/common" \
  "$SCRIPT_DIR/langs/$DETECTED_LANG" \
  "$TARGET" \
  "$FORCE" \
  "$DRY_RUN" || exit $?

log_section "4/5  Merging .claude/settings.json"
merge_settings \
  "$SCRIPT_DIR/common/.claude/settings.json" \
  "$SCRIPT_DIR/langs/$DETECTED_LANG/.claude/settings.json" \
  "$TARGET/.claude/settings.json" \
  "$DRY_RUN" || exit $?

if [[ "$SKIP_SKILLS" -eq 0 ]]; then
  log_section "5/5  Installing recommended Claude Code plugins"
  install_skills "$DRY_RUN"
else
  log_section "5/5  Plugin installation skipped (--skip-skills)"
fi

log_section "Done"
log_ok "language:        $DETECTED_LANG"
log_ok "files copied:    common/ + langs/$DETECTED_LANG/"
log_ok "settings merged: $TARGET/.claude/settings.json"
if [[ "$MISSING_COUNT" -gt 0 ]]; then
  log_warn "missing OS tools: ${MISSING_DEPS[*]}"
  log_warn "review the warnings above and install the missing tools before working in this project"
fi
log_info "next: git init && git add . && git commit -m 'Bootstrap from base-files'"
```

```bash
chmod +x install.sh
```

- [ ] **Step 2: Smoke check — `--help`**

```bash
cd /home/tonny/projects/00.base-files
./install.sh --help
```

Expected: usage text appears and exit code 0.

- [ ] **Step 3: Smoke check — `--dry-run` in a fresh tmp dir with a Gemfile**

```bash
TMP="$(mktemp -d)"
( cd "$TMP" && touch Gemfile && /home/tonny/projects/00.base-files/install.sh --dry-run --skip-skills )
ls "$TMP"
rm -rf "$TMP"
```

Expected: the script reports `language: rails`, "(dry-run) would copy ..." for each file, and the tmp directory remains empty.

- [ ] **Step 4: Commit**

```bash
cd /home/tonny/projects/00.base-files
git add install.sh
git commit -m "feat: add install.sh entry point wiring all five phases"
```

---

## Task 24: VERSION and README.md

**Files:**
- Create: `VERSION`
- Create: `README.md`

- [ ] **Step 1: Write `VERSION`**

Write `/home/tonny/projects/00.base-files/VERSION`:

```
0.1.0
```

- [ ] **Step 2: Write `README.md`**

Write `/home/tonny/projects/00.base-files/README.md`:

````markdown
# base-files

Multi-language base template for new projects. One command installs common
guidance, language-specific tooling, and Claude Code plugins into a fresh
project directory.

Supported overlays: **Rails 8 · Python (FastAPI/Django) · Go**.

## Quick start

```bash
mkdir -p ~/projects/my-app && cd ~/projects/my-app
# (initialize the framework first, e.g. `rails new .` / `uv init` / `go mod init ...`)
~/projects/00.base-files/install.sh
```

The installer:

1. Detects the language from `Gemfile` / `pyproject.toml` (or `requirements.txt`, `Pipfile`) / `go.mod`.
2. Verifies OS tools are present (`jq`, `git`, language runtime). **Reports** missing tools; never installs them automatically.
3. Copies `common/` + the matching `langs/<lang>/` into the current directory, backing up any conflicting file with a timestamp suffix.
4. Deep-merges the two `settings.json` files into `.claude/settings.json` and validates the result with `jq`.
5. Adds the recommended marketplaces and installs the recommended plugins via `claude plugin`. Skipped with `--skip-skills`.

## Options

| Flag             | Purpose                                                          |
|------------------|------------------------------------------------------------------|
| `--lang <x>`     | Override auto-detection (`rails`, `python`, `go`)                |
| `--dry-run`      | Print the plan; do not write files or invoke `claude plugin`     |
| `--force`        | Overwrite existing files (backed up with `*.bak.YYYYMMDD-HHMMSS`)|
| `--skip-skills`  | Skip plugin installation entirely                                |
| `-h`, `--help`   | Show usage                                                       |

## What gets installed

```text
<project>/
├── CLAUDE.md
├── docs/standards/
│   ├── RULES.md       (common)
│   ├── WORKFLOW.md    (common)
│   ├── QUALITY.md     (common — principles only)
│   ├── REVIEW.md      (common)
│   ├── STACK.md       (language overlay)
│   └── TOOLS.md       (language overlay)
└── .claude/
    ├── settings.json  (common hooks + language hooks, deep-merged)
    └── hooks/
        └── pipeline-reminder.txt
```

## Recommended Claude Code plugins (auto-installed)

| Plugin                    | Marketplace                               | Purpose                                |
|---------------------------|-------------------------------------------|----------------------------------------|
| `superpowers`             | `anthropics/claude-plugins-official`      | Brainstorm / plan / TDD / debug / review |
| `code-review`             | `anthropics/claude-plugins-official`      | Branch / PR review                     |
| `andrej-karpathy-skills`  | `forrestchang/andrej-karpathy-skills`     | Karpathy coding guardrails             |

`graphify` is **verified** (not installed) by the installer. Install it
manually if you want knowledge-graph-driven code search.

## Hacking on this template

Run the test suite from the template root:

```bash
./tests/run_all.sh
```

Each lib module has a focused test under `tests/`. The end-to-end smoke tests
(`tests/smoke_rails.sh`, `tests/smoke_python.sh`, `tests/smoke_go.sh`,
`tests/smoke_empty.sh`) drive the installer against scratch directories.

## Troubleshooting

- **"claude CLI not found"** — install Claude Code first; the installer falls
  through with a warning and your files are still placed.
- **"jq missing"** — the installer will still copy files but `merge-settings`
  will fail. Install `jq` (`brew install jq` or `apt install jq`).
- **Conflict resolution stuck** — re-run with `--force` to bypass per-file
  prompts; existing files are still backed up.
- **Wrong language detected** — re-run with `--lang <correct>`.
````

- [ ] **Step 3: Commit**

```bash
cd /home/tonny/projects/00.base-files
git add VERSION README.md
git commit -m "docs: add README.md and VERSION 0.1.0"
```

---

## Task 25: Tear down the now-empty docs/standards/ and .claude/ at root

After Tasks 1–10 moved every file out of `docs/standards/` and `.claude/`, the
empty directories and the redundant root `CLAUDE.md` remain. This task cleans
them up.

**Files:**
- Delete: `CLAUDE.md` (root)
- Delete: `docs/standards/` (empty)
- Delete: `.claude/hooks/` (empty)
- Delete: `.claude/` (empty)

- [ ] **Step 1: Verify directories are empty (other than removed files)**

```bash
cd /home/tonny/projects/00.base-files
ls -la docs/standards/ 2>/dev/null
ls -la .claude/ 2>/dev/null
ls -la .claude/hooks/ 2>/dev/null
```

Expected: each `ls` shows only `.` and `..` (or the directory is already gone). If extra files remain, stop and investigate before proceeding.

- [ ] **Step 2: Remove the redundant root CLAUDE.md (now superseded by common/CLAUDE.md)**

```bash
cd /home/tonny/projects/00.base-files
git rm CLAUDE.md
```

- [ ] **Step 3: Remove the empty directories**

```bash
rmdir docs/standards 2>/dev/null || true
rmdir .claude/hooks  2>/dev/null || true
rmdir .claude        2>/dev/null || true
```

`rmdir` only succeeds when the directory is empty; the `|| true` keeps the script alive if a directory is already absent.

- [ ] **Step 4: Verify the cleanup**

```bash
cd /home/tonny/projects/00.base-files
ls -la
```

Expected: top-level contains `install.sh`, `README.md`, `VERSION`, `.gitignore`, `common/`, `langs/`, `lib/`, `tests/`, `docs/`, `.git/`. No `CLAUDE.md`, no `.claude/`, and `docs/` contains only `superpowers/`.

- [ ] **Step 5: Commit**

```bash
git commit -m "chore: remove old root CLAUDE.md and empty docs/standards, .claude dirs"
```

---

## Task 26: Top-level test runner

**Files:**
- Create: `tests/run_all.sh`

- [ ] **Step 1: Write the runner**

Write `/home/tonny/projects/00.base-files/tests/run_all.sh`:

```bash
#!/usr/bin/env bash
# tests/run_all.sh — run every tests/test_*.sh and report pass/fail.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0; FAILED=()

shopt -s nullglob
for t in "$HERE"/test_*.sh; do
  printf '\n=== Running %s ===\n' "$(basename "$t")"
  if "$t"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILED+=("$(basename "$t")")
  fi
done

printf '\n--- Summary ---\n'
printf 'passed: %d\nfailed: %d\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed tests:\n'
  for t in "${FAILED[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
```

```bash
chmod +x tests/run_all.sh
```

- [ ] **Step 2: Run all unit tests**

```bash
cd /home/tonny/projects/00.base-files
./tests/run_all.sh
```

Expected: each `test_*.sh` reports `ALL PASS`; final summary shows `failed: 0` and exit code 0.

- [ ] **Step 3: Commit**

```bash
git add tests/run_all.sh
git commit -m "test: add top-level run_all.sh test runner"
```

---

## Task 27: End-to-end smoke tests (four scenarios from spec §8)

**Files:**
- Create: `tests/smoke_rails.sh`
- Create: `tests/smoke_python.sh`
- Create: `tests/smoke_go.sh`
- Create: `tests/smoke_empty.sh`

Each smoke test creates a scratch directory, drops a manifest, runs the installer with `--dry-run --skip-skills`, and asserts that the right overlay was selected and `dry-run` correctly avoided writing files. A separate `--force` real-write assertion follows in each case.

- [ ] **Step 1: Write `tests/smoke_rails.sh`**

Write `/home/tonny/projects/00.base-files/tests/smoke_rails.sh`:

```bash
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
```

```bash
chmod +x tests/smoke_rails.sh
```

- [ ] **Step 2: Write `tests/smoke_python.sh`**

Write `/home/tonny/projects/00.base-files/tests/smoke_python.sh`:

```bash
#!/usr/bin/env bash
# smoke_python.sh — pyproject.toml present → python overlay applied.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
touch "$TMP/pyproject.toml"

out=$( cd "$TMP" && "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
echo "$out" | grep -q "language: python" || fail "dry-run did not detect python"
ok "dry-run detects python"

( cd "$TMP" && "$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 ) || fail "real install exited non-zero"
[[ -f "$TMP/docs/standards/STACK.md" ]] || fail "Python STACK.md missing"
grep -q "Python" "$TMP/docs/standards/STACK.md" || fail "STACK.md does not look like the Python overlay"
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("ruff")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference ruff"
ok "real run installs python overlay"

echo "smoke_python.sh: ALL PASS"
```

```bash
chmod +x tests/smoke_python.sh
```

- [ ] **Step 3: Write `tests/smoke_go.sh`**

Write `/home/tonny/projects/00.base-files/tests/smoke_go.sh`:

```bash
#!/usr/bin/env bash
# smoke_go.sh — go.mod present → go overlay applied.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
touch "$TMP/go.mod"

out=$( cd "$TMP" && "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
echo "$out" | grep -q "language: go" || fail "dry-run did not detect go"
ok "dry-run detects go"

( cd "$TMP" && "$ROOT/install.sh" --force --skip-skills >/dev/null 2>&1 ) || fail "real install exited non-zero"
grep -q "Go" "$TMP/docs/standards/STACK.md" || fail "STACK.md does not look like the Go overlay"
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("gofmt")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference gofmt"
ok "real run installs go overlay"

echo "smoke_go.sh: ALL PASS"
```

```bash
chmod +x tests/smoke_go.sh
```

- [ ] **Step 4: Write `tests/smoke_empty.sh`**

Write `/home/tonny/projects/00.base-files/tests/smoke_empty.sh`:

```bash
#!/usr/bin/env bash
# smoke_empty.sh — empty target with no override → non-interactive mode fails fast.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Non-interactive ambiguous: should fail with mention of --lang.
set +e
out=$( cd "$TMP" && BASE_FILES_NONINTERACTIVE=1 "$ROOT/install.sh" --dry-run --skip-skills 2>&1 )
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "non-interactive empty dir should exit non-zero (got $rc)"
echo "$out" | grep -q -- "--lang" || fail "error message should mention --lang"
ok "non-interactive empty dir rejected with hint"

# With --lang go, it succeeds.
( cd "$TMP" && "$ROOT/install.sh" --lang go --force --skip-skills >/dev/null 2>&1 ) || fail "install with --lang go failed"
grep -q "Go" "$TMP/docs/standards/STACK.md" || fail "Go overlay not applied"
ok "--lang override works in empty dir"

echo "smoke_empty.sh: ALL PASS"
```

```bash
chmod +x tests/smoke_empty.sh
```

- [ ] **Step 5: Update `tests/run_all.sh` to include the smoke tests**

The runner already globs `test_*.sh`. Smoke tests use the prefix `smoke_*.sh` so they don't run by default (they are slower and shell out to the real installer). Add a second loop after the unit-test loop:

Edit `/home/tonny/projects/00.base-files/tests/run_all.sh`. Replace the body between `shopt -s nullglob` and `printf '\n--- Summary ---\n'` with:

```bash
shopt -s nullglob
for t in "$HERE"/test_*.sh; do
  printf '\n=== Running %s ===\n' "$(basename "$t")"
  if "$t"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILED+=("$(basename "$t")")
  fi
done

if [[ "${RUN_SMOKE:-0}" == "1" ]]; then
  for t in "$HERE"/smoke_*.sh; do
    printf '\n=== Running %s ===\n' "$(basename "$t")"
    if "$t"; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1))
      FAILED+=("$(basename "$t")")
    fi
  done
fi
```

- [ ] **Step 6: Run unit tests + smoke tests**

```bash
cd /home/tonny/projects/00.base-files
./tests/run_all.sh
RUN_SMOKE=1 ./tests/run_all.sh
```

Expected: both invocations end with `failed: 0`. Smoke tests should each report `ALL PASS`.

- [ ] **Step 7: Commit**

```bash
git add tests/smoke_rails.sh tests/smoke_python.sh tests/smoke_go.sh tests/smoke_empty.sh tests/run_all.sh
git commit -m "test: add end-to-end smoke tests for each language overlay"
```

---

## Self-Review Notes

After writing the plan, I checked it against the design spec:

1. **Spec coverage:**
   - §3 (5 locked decisions) → Tasks cover all five: layout (Tasks 1–16), install scenario (Task 23), language detection (Task 18), OS-only-check policy (Task 19), claude-plugin auto-install (Task 22).
   - §4 (folder layout) → fully materialized by Tasks 1–16, 23.
   - §5 (installer design) → entry point in Task 23, phases delegated to Tasks 17–22.
   - §6 (plugin auto-install) → Task 22.
   - §7 (common-core hooks) → Task 10. Language hooks: Tasks 3, 13, 16.
   - §8 (migration) → Tasks 0, 1, 2, 4, 5, 9, 25 (the moves and cleanup).
   - §8 step 5 (validation scenarios) → Task 27.
2. **Placeholder scan:** No "TBD" / "TODO" / "fill in later" remains. Every code block contains the complete content.
3. **Type consistency:** Function names referenced across tasks (`detect_language`, `check_deps`, `copy_files`, `merge_settings`, `install_skills`) appear consistently in the entry point (Task 23) and their own tests (Tasks 17–22).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-21-multi-language-base-template.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
