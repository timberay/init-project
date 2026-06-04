# Usage Guide

Detailed reference for using `init-project` (also known as `base-files`) to
bootstrap a new Ruby on Rails, Python, Go, Bash/Shell, or Next.js project with
Claude Code guidance, pre-commit hooks, and recommended plugins.

For a one-page quick start, see [README](../README.md). This document is the
deeper companion that covers every flag, every phase, every edge case, and how
to extend the template to a new language.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Installing the template once](#3-installing-the-template-once)
4. [Bootstrapping a new project](#4-bootstrapping-a-new-project)
5. [The six installer phases in detail](#5-the-six-installer-phases-in-detail)
6. [Command-line flags reference](#6-command-line-flags-reference)
7. [Walkthroughs](#7-walkthroughs)
8. [What you get](#8-what-you-get)
9. [Recommended Claude Code plugins](#9-recommended-claude-code-plugins)
10. [Re-running on an existing project](#10-re-running-on-an-existing-project)
11. [Customizing for your team](#11-customizing-for-your-team)
12. [Adding a new language overlay](#12-adding-a-new-language-overlay)
13. [Troubleshooting](#13-troubleshooting)
14. [Testing the template itself](#14-testing-the-template-itself)
15. [Repository layout](#15-repository-layout)
16. [Design rationale](#16-design-rationale)

---

## 1. Overview

`init-project` is a **template-and-installer** pair, not a code library and
not a framework scaffolder. Its job is to drop a consistent set of guidance
documents and Claude Code hook configuration into every new project you start,
so that you (and Claude) approach Rails, Python, Go, shell-first, and Next.js
projects with the same discipline and the right tooling.

Concretely, `install.sh` does six things, in order, in roughly five seconds:

1. Detects which language overlay applies, from the project's manifest file.
2. Reports any missing OS-level tools (without installing them).
3. Copies the common documentation tree plus the matching language overlay
   into the project's working directory.
4. Deep-merges the common Claude Code hook settings with the language-specific
   hooks into a single `.claude/settings.json`.
5. Creates compatibility links so Claude Code and Codex share project skills.
6. Installs the recommended Claude Code plugins via the official
   `claude plugin` CLI (idempotent — already-installed plugins are skipped).

The template intentionally does **not** scaffold framework code. You are
expected to run `rails new .`, `uv init`, `go mod init <module>`,
`npx create-next-app@latest .`, or your preferred shell project setup yourself.
The template adds the guidance and hooks *around* that framework, not in place
of it. If no manifest exists yet, the installer applies the `bash` overlay by
default.

---

## 2. Prerequisites

You need these on the machine before running the installer.

### Hard requirements

| Tool           | Why                                                      | Install hint                                         |
|----------------|----------------------------------------------------------|------------------------------------------------------|
| `bash` ≥ 4.0   | The installer and its modules use bash-only features.    | macOS ships with bash 3.2 — install bash 5 via Homebrew (`brew install bash`) and run the installer with that bash explicitly. |
| `git`          | Cloning the template and recording installation commits. | `sudo apt install -y git` / `brew install git`       |
| `jq`           | Validating and merging `settings.json` files.            | `sudo apt install -y jq` / `brew install jq`         |

### Soft requirements

| Tool      | Why                                                                         | Notes                                       |
|-----------|-----------------------------------------------------------------------------|---------------------------------------------|
| `claude`  | Installing the recommended Claude Code plugins automatically.                | If absent, the installer skips phase 6 with a warning and your files are still placed. |
| `gh`      | Convenient for the subsequent step of creating a remote repository.          | Not used by the installer itself.           |
| Language runtime | The matching runtime for your overlay (`ruby`, `python3`, `go`, `bash`, or `node`/`npm`). | Reported but not installed by the installer. |

The installer will report any missing tool with the exact install command for
your platform. It never installs anything system-wide on your behalf.

---

## 3. Installing the template once

You only need to do this once per machine. Pick a directory you do not move
later — the installer references it by absolute path from every project you
bootstrap.

### 3.1 Clone the template

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/timberay/init-project.git 00.base-files
```

(The `00.` prefix is purely for sort order — it floats the template to the
top of `~/projects` so it's easy to find. Any directory name works.)

### 3.2 Smoke check

```bash
~/projects/00.base-files/install.sh --help
```

You should see usage text and exit code 0. If you get "permission denied",
make sure `install.sh` is executable:

```bash
chmod +x ~/projects/00.base-files/install.sh
```

### 3.3 Optional: add a shell alias

```bash
# In ~/.bashrc or ~/.zshrc
alias init-project='~/projects/00.base-files/install.sh'
```

Now you can run `init-project` from any directory.

### 3.4 Keeping the template current

```bash
cd ~/projects/00.base-files
git pull
```

The template version is tracked in the `VERSION` file (semver). Major bumps
may change which files are placed or how settings are merged — read the
release notes / `git log` before pulling a major bump.

---

## 4. Bootstrapping a new project

The installer is designed to be the **second** command you run in a new
project, right after the framework scaffolder.

### Rails 8

```bash
# 1. Scaffold Rails first
mkdir -p ~/projects/my-rails-app && cd ~/projects/my-rails-app
rails new . --skip-bundle      # or however you start Rails projects

# 2. Then bootstrap the template
~/projects/00.base-files/install.sh

# 3. Initialize git (if Rails didn't already)
git init && git add . && git commit -m "Initial commit"
```

### Python (FastAPI or Django)

```bash
# 1. Initialize the project with uv (or poetry, or pip-tools)
mkdir -p ~/projects/my-py-app && cd ~/projects/my-py-app
uv init
uv add fastapi              # any framework you prefer

# 2. Then bootstrap the template
~/projects/00.base-files/install.sh

# 3. Commit
git init && git add . && git commit -m "Initial commit"
```

### Go

```bash
mkdir -p ~/projects/my-go-app && cd ~/projects/my-go-app
go mod init github.com/myorg/my-go-app

~/projects/00.base-files/install.sh

git init && git add . && git commit -m "Initial commit"
```

### Next.js

```bash
mkdir -p ~/projects/my-next-app && cd ~/projects/my-next-app
npx create-next-app@latest .

~/projects/00.base-files/install.sh

git init && git add . && git commit -m "Initial commit"
```

### Empty directory (no manifest yet)

If you run the installer in an empty directory, language auto-detection
defaults to the `bash` overlay:

```bash
mkdir -p ~/projects/blank && cd ~/projects/blank
~/projects/00.base-files/install.sh
```

Pass `--lang <rails|python|go|bash|nextjs>` when you already know the target
stack and want to override detection.

---

## 5. The six installer phases in detail

The installer announces each phase with a colored section header. Knowing
what each phase does helps you read the output and recover from partial runs.

### Phase 1 — Detect language

Looks for manifest files in the current working directory, in this priority
order:

| Manifest found            | Overlay applied |
|---------------------------|-----------------|
| `Gemfile` or `*.gemspec`  | `rails`         |
| `pyproject.toml`, `requirements.txt`, or `Pipfile` | `python` |
| `go.mod`                  | `go`            |
| `package.json` with a `next` dependency, or `next.config.*` | `nextjs` |
| (none)                    | `bash`          |

The `--lang` flag overrides detection unconditionally.

### Phase 2 — Check OS dependencies

Probes the PATH for `jq`, `git`, and the relevant language runtime. Anything
missing is logged with a `[WARN]` line and the install hint for your platform.

**No tool is ever installed by this phase.** The intent is to surface problems
early without touching your machine's package manager.

If the count of missing tools is greater than zero, you'll see a final
summary line listing them all so you can install them in one batch.

### Phase 3 — Copy files

Walks the `common/` tree and the matching `langs/<detected>/` tree, copying
every file into the target directory. Two safeties:

- **`.claude/settings.json` is skipped** in this phase — phase 4 handles it
  by merging.
- **Existing files** are either backed up with a timestamp suffix
  (`*.bak.YYYYMMDD-HHMMSS`) and overwritten (in `--force` mode), or you are
  prompted per file: `[o]verwrite (with backup) / [s]kip / [q]uit`.

### Phase 4 — Merge settings.json

`jq -s reduce` concatenates the `hooks.SessionStart`, `hooks.PreToolUse`,
`hooks.PostToolUse`, and `hooks.UserPromptSubmit` arrays from the common and
language-specific `settings.json` files. The result is validated with
`jq empty` before being atomically moved into place at
`<project>/.claude/settings.json`.

This is why the language overlay can carry only its own hooks (pre-commit
test, lint, file-formatter) without needing to repeat the common ones
(graphify reminder, pipeline reminder).

### Phase 5 — Create agent compatibility links

Creates `.claude/skills -> ../.agents/skills` so Claude Code can use the same
project skills that Codex scans natively from `.agents/skills`.

If `.claude/skills` already exists, `install.sh` leaves it alone unless
`--force` is used. With `--force`, the existing path is backed up before the
symlink is created.

---

### Phase 6 — Install Claude Code plugins

Runs the official `claude plugin` CLI to:

1. Add the recommended marketplaces, if absent:
   - `anthropics/claude-plugins-official`
   - `forrestchang/andrej-karpathy-skills`
2. Install the recommended plugins, if absent:
   - `superpowers@claude-plugins-official`
   - `code-review@claude-plugins-official`
   - `andrej-karpathy-skills@karpathy-skills`
3. Verify (without installing) that the `graphify` and `gstack` skills are
   present in `~/.agents/skills/<name>/` or legacy `~/.claude/skills/<name>/`.
   These two live outside the claude plugin marketplaces and are installed
   separately by each team. If absent, you get a warning with a hint —
   `gstack` is required for `WORKFLOW.md` phases 1, 2, and 6.

This phase is **idempotent** — re-running the installer never re-adds an
already-installed marketplace or plugin. Use `--skip-skills` to skip this
phase entirely (e.g., in CI or when `claude` CLI is not on PATH).

---

## 6. Command-line flags reference

| Flag             | Default | Effect |
|------------------|---------|--------|
| `--lang <x>`     | auto-detect | Force the overlay to `rails`, `python`, `go`, `bash`, or `nextjs`. Skips manifest detection. |
| `--dry-run`      | off     | Print the plan and exit. No files written, no `claude plugin` calls made. Safe to run anywhere. |
| `--force`        | off     | Skip the per-file overwrite prompt. Existing files are always backed up with a timestamp suffix and overwritten. Pair with `--dry-run` to see exactly what would change. |
| `--skip-skills`  | off     | Skip phase 6 (plugin installation) entirely. Use this when `claude` CLI is missing, in CI, or when you manage plugins another way. |
| `-h`, `--help`   |         | Print usage and exit 0. |

### Useful combinations

```bash
# Preview without writing anything
~/projects/00.base-files/install.sh --dry-run

# Force overwrite, but still see what would happen first
~/projects/00.base-files/install.sh --dry-run --force

# CI-friendly: explicit overlay, overwrite prompts skipped, no plugin install
BASE_FILES_NONINTERACTIVE=1 ~/projects/00.base-files/install.sh \
    --lang go --force --skip-skills

# Re-bootstrap an existing project after the template was updated
~/projects/00.base-files/install.sh --force
```

### Environment variables

| Variable                       | Effect |
|--------------------------------|--------|
| `BASE_FILES_NONINTERACTIVE=1`  | Reserved for non-interactive runs. Language detection now defaults to `bash` when no manifest exists; pair this with `--force` in CI to avoid file-conflict prompts. |
| `NO_COLOR=1`                   | Suppress ANSI color codes in logger output. Useful for piping to a file or log aggregator. Must be set BEFORE the installer runs (the color decision is captured at source-time inside `lib/log.sh`). |
| `REQUIRED_OS=(...)`            | Override the list of OS-level tools the installer probes in phase 2. Mainly for testing. |
| `REQUIRED_LANG_rails=(...)`    | Override the Ruby-side runtime list (default: `ruby`). |
| `REQUIRED_LANG_python=(...)`   | Override the Python-side runtime list (default: `python3`). |
| `REQUIRED_LANG_go=(...)`       | Override the Go-side runtime list (default: `go`). |
| `REQUIRED_LANG_bash=(...)`     | Override the Bash-side runtime list (default: `bash`). |
| `REQUIRED_LANG_nextjs=(...)`   | Override the Next.js-side runtime list (default: `node npm`). |

### Exit codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 2    | Unknown CLI argument, or invalid `--lang` value |
| 3    | Ambiguous language and `BASE_FILES_NONINTERACTIVE=1` was set |
| 4    | User aborted at the per-file overwrite prompt |
| 5    | Missing input `settings.json` for the merge phase (file integrity issue) |
| 6    | `jq` merge command failed |
| 7    | Merged `settings.json` is not valid JSON |

---

## 7. Walkthroughs

### 7.1 Walkthrough — Rails 8 (full sequence)

```bash
# Create the directory
mkdir -p ~/projects/booklist && cd ~/projects/booklist

# Scaffold Rails (without bundle install yet, for speed)
rails new . --skip-bundle --skip-test --skip-system-test --css=tailwind

# Bundle install on your own
bundle install

# Now bootstrap the template
~/projects/00.base-files/install.sh
# Expected output:
#   == 1/6  Detecting language ==
#   [OK] language: rails
#   == 2/6  Checking OS dependencies ==
#   [OK] jq found / git found / ruby found
#   == 3/6  Copying common + rails files ==
#   [OK] copied ... (many lines)
#   == 4/6  Merging .claude/settings.json ==
#   [OK] merged settings.json -> ...
#   == 5/6  Creating agent compatibility links ==
#   [OK] linked .../.claude/skills -> ../.agents/skills
#   == 6/6  Installing recommended Claude Code plugins ==
#   [INFO] marketplace already added: claude-plugins-official
#   [INFO] plugin already installed: superpowers@claude-plugins-official
#   ... etc

# Verify
ls docs/standards/                    # RULES, WORKFLOW, QUALITY, REVIEW, STACK, TOOLS
cat .claude/settings.json | jq '.hooks | keys'
# → ["PostToolUse", "PreToolUse", "UserPromptSubmit"]

# Commit
git add .
git commit -m "Initial commit"
```

The next time you say "implement feature X" to Claude in this project, the
`UserPromptSubmit` hook will detect the feature-request keyword and inject
the six-phase pipeline reminder. The pre-commit hook will run
`bin/rails test` and `bin/rubocop` before letting you commit.

### 7.2 Walkthrough — Python with uv + FastAPI

```bash
mkdir -p ~/projects/inventory-api && cd ~/projects/inventory-api

# Use uv as the dep manager
uv init
uv add fastapi uvicorn sqlalchemy psycopg2-binary
uv add --dev pytest ruff mypy

# Bootstrap the template
~/projects/00.base-files/install.sh
# → language: python (detected from pyproject.toml)
# → ruby NOT probed; only python3 + OS deps probed

# Verify
cat .claude/settings.json | jq '.hooks.PreToolUse[].hooks[].command' | grep -E "pytest|ruff"
# → both pytest and ruff appear, gated by Bash(git commit*)

# Sanity-check the pre-commit hook locally
echo "def add(a, b): return a + b" > app.py
echo "import pytest; def test_add(): from app import add; assert add(2, 3) == 5" > test_app.py
uv run pytest -q          # passes
uv run ruff check .       # passes

git init && git add . && git commit -m "Initial commit"
```

### 7.3 Walkthrough — Go with chi router

```bash
mkdir -p ~/projects/url-shortener && cd ~/projects/url-shortener

# Start the Go module
go mod init github.com/myorg/url-shortener
go get github.com/go-chi/chi/v5

# Bootstrap
~/projects/00.base-files/install.sh
# → language: go

# Hooks now include go test + golangci-lint pre-commit and gofmt+vet
# PostToolUse on .go files

cat .claude/settings.json | jq '.hooks.PostToolUse[].hooks[].command'
# → references gofmt and go vet

git init && git add . && git commit -m "Initial commit"
```

### 7.4 Walkthrough — preview before committing

When you're unsure what the installer will do, dry-run first:

```bash
cd ~/projects/some-existing-project
~/projects/00.base-files/install.sh --dry-run

# Output (excerpt):
#   == 3/5  Copying common + rails files ==
#   [*] (dry-run) would copy .../common/CLAUDE.md -> ./CLAUDE.md
#   [*] (dry-run) would copy .../common/docs/standards/RULES.md -> ./docs/standards/RULES.md
#   ... (one line per file)
#   == 4/5  Merging .claude/settings.json ==
#   [*] (dry-run) would merge .../common/.claude/settings.json + .../langs/rails/.claude/settings.json -> ./.claude/settings.json
```

No files are touched. Once you're happy, re-run without `--dry-run`.

---

## 8. What you get

After a successful run, the target project contains:

```
<project>/
├── CLAUDE.md                          # Global guidance for Claude Code
├── docs/
│   └── standards/
│       ├── RULES.md                   # DRY, Tidy First, AI-instruction-writing — language-neutral
│       ├── WORKFLOW.md                # Six-phase pipeline for new feature work
│       ├── QUALITY.md                 # Test pyramid, security principles, accessibility, perf
│       ├── REVIEW.md                  # Code-review checklist
│       ├── STACK.md                   # Framework-specific tech stack (Rails / Python / Go / Bash)
│       └── TOOLS.md                   # Framework-specific dev commands & linters
├── PROJECT_STATE.md                  # Orchestrator state — "where the project is right now", refreshed via /state-sync
├── docs/decisions/                   # Append-only ADR log (decisions live here, not in git log)
│   ├── README.md                     # ADR index (one row per ADR)
│   └── ADR-0000-orchestrator-bootstrap.md
└── .claude/
    ├── settings.json                  # Merged hook config: orchestrator (SessionStart inject + PreToolUse stale-check + UserPromptSubmit ADR reminder),
    │                                  #   graphify reminder + pipeline reminder + pre-commit (test runner + linter) + post-Write/Edit auto-format
    ├── hooks/
    │   ├── pipeline-reminder.txt      # Context injected by the pipeline-phase UserPromptSubmit hook
    │   ├── sessionstart-inject-state.sh   # Reads PROJECT_STATE.md + docs/decisions/README.md, injects as session context
    │   ├── userpromptsubmit-remind.sh     # Reminds Claude to consult docs/decisions/ when the user references prior decisions
    │   └── pretooluse-stale-check.sh      # Warns before Edit/Write/NotebookEdit if PROJECT_STATE.md is >7 days stale
    ├── commands/
    │   ├── decide.md                  # /decide — draft a new ADR from conversation context
    │   ├── state-sync.md              # /state-sync — refresh PROJECT_STATE.md
    │   └── supersede.md               # /supersede ADR-NNNN — reverse a previously accepted ADR
    └── skills/
        └── push2gh/
            └── SKILL.md               # Project-bundled skill: commit → push → PR → cleanup
```

### What each file is for

- **`CLAUDE.md`** is the first thing Claude Code reads in any session. It
  establishes non-negotiable rules (Korean explanations, TDD, Tidy First,
  small commits), points to the standards documents, and lists the
  behavioral guidelines (Think Before Coding, Simplicity First, Surgical
  Changes, Goal-Driven Execution).

- **`docs/standards/RULES.md`** is the meta-guide: DRY, Tidy First, small
  commits, documentation rules, and how to write good AI instructions.
  Language-neutral. Reads once a quarter.

- **`docs/standards/WORKFLOW.md`** specifies the six-phase pipeline for new
  feature work (product → architecture → technical design → task breakdown
  → execute → ship). The `UserPromptSubmit` hook reminds Claude of this
  pipeline whenever you mention a feature-request keyword.

- **`docs/standards/QUALITY.md`** defines the test pyramid, universal
  security principles, accessibility standards, and performance guidelines.
  Concrete tool names (rubocop, pytest, gofmt) live in the language-specific
  `TOOLS.md`.

- **`docs/standards/REVIEW.md`** is the checklist you (or a reviewer) run
  before approving a PR. References `TOOLS.md` for the language-specific
  automated gate.

- **`docs/standards/STACK.md`** (language overlay) is the deepest
  language-specific document — framework choice, ORM, migrations,
  background jobs, caching, security guardrails, deployment patterns.

- **`docs/standards/TOOLS.md`** (language overlay) lists the exact commands
  for tests, linters, type-checking, security scanning, migrations, and
  running the app.

- **`AGENTS.md`** is the project guidance file for Codex, opencode, and other
  agents that read the AGENTS.md convention. Claude Code reads `CLAUDE.md`;
  keep both files aligned when changing durable policy.

- **`opencode.json`** points opencode at `AGENTS.md` and the standards docs,
  and sets conservative project permissions for edits, Bash commands, and
  external-directory access.

- **`.codex/hooks.json`** wires Codex hook events to the shared scripts in
  `.agent-hooks/`. Current Codex releases enable hooks by default; no
  `codex_hooks = true` flag is required.

- **`.claude/settings.json`** is the merged Claude hook config. The `SessionStart`
  hook injects `PROJECT_STATE.md` + the ADR index into the session's first
  context. `UserPromptSubmit` hooks inject the pipeline reminder (on
  feature-request keywords) and the ADR reminder (on prior-decision keywords).
  The `PreToolUse` stale-check warns before Edit/Write if PROJECT_STATE.md is
  >7 days old; other `PreToolUse` hooks run the test suite and linter before
  `git commit`; `PostToolUse` hooks auto-format the file you just edited.

- **`.agent-hooks/pipeline-reminder.txt`** is the context message the
  pipeline-phase `UserPromptSubmit` hook injects when triggered.

- **`.agent-hooks/sessionstart-inject-state.sh`**,
  **`userpromptsubmit-remind.sh`**, **`userpromptsubmit-pipeline.sh`**,
  **`pretooluse-stale-check.sh`**, and **`security-check.sh`** are the shared
  hook scripts used by Claude Code and Codex. See
  `docs/decisions/ADR-0000-orchestrator-bootstrap.md` for the rationale.

- **`.claude/commands/{decide,state-sync,supersede}.md`** are the three
  orchestrator slash commands. `/decide` drafts a new ADR; `/state-sync`
  refreshes `PROJECT_STATE.md`; `/supersede ADR-NNNN` reverses a previously
  accepted ADR.

- **`PROJECT_STATE.md`** is the project's "where are we right now" page —
  one screen, six fixed sections, mutable. The `SessionStart` hook injects
  it on every session. Refresh with `/state-sync` at phase transitions.

- **`docs/decisions/`** is the append-only ADR directory. Decisions are
  immutable once `Accepted`; reversal requires `/supersede`. See
  `ADR-0000-orchestrator-bootstrap.md` for the system itself.

### What does NOT get installed

The installer never touches:

- Your shell rc files (`.bashrc`, `.zshrc`, etc.)
- Global Claude Code config (`~/.claude/CLAUDE.md`, `~/.claude/settings.json`)
- Global Codex config (`~/.codex/AGENTS.md`, `~/.codex/hooks.json`)
- Global opencode config (`~/.config/opencode/AGENTS.md`, `opencode.json`)
- Anything in `/usr/local/` or system-wide locations
- Your language runtime, ORM, framework, or any package

The only global side-effect is in phase 6, which uses the official
`claude plugin` CLI to add marketplaces and install plugins under
`~/.claude/plugins/`. Use `--skip-skills` to suppress even that.

---

## 9. Recommended Claude Code plugins

| Plugin                       | Marketplace                                    | What it adds                                                                  |
|------------------------------|------------------------------------------------|-------------------------------------------------------------------------------|
| **`superpowers`**            | `anthropics/claude-plugins-official`           | The six-phase development pipeline — brainstorming, writing-plans, executing-plans, TDD, debugging, verification |
| **`code-review`**            | `anthropics/claude-plugins-official`           | Branch/PR pre-landing review                                                   |
| **`andrej-karpathy-skills`** | `forrestchang/andrej-karpathy-skills`          | Karpathy's coding-mistake guardrails — surgical changes, no overengineering    |

These are installed by phase 6. Two more skills are **verified, not
installed** — the installer checks `~/.agents/skills/<name>/` first, then the
legacy `~/.claude/skills/<name>/`, and warns if
absent:

| Skill      | Why it lives outside the marketplaces                                 | Required for                                       |
|------------|-----------------------------------------------------------------------|----------------------------------------------------|
| `graphify` | Standalone CLI + skill bundle; not packaged as a claude plugin        | Knowledge-graph-driven code search (optional)      |
| `gstack`   | Internal toolkit installed separately by each team                    | `WORKFLOW.md` phases 1, 2, 6 (`/office-hours`, `/plan-eng-review`, `/review`, `/ship`, `/land-and-deploy`, `/document-release`) |

If `gstack` is absent, you can still use the template — phases 3, 4, 5 work
with `superpowers` alone — but phases 1, 2, and 6 need manual product /
architecture / release notes in place of the missing skills.

### Bundled project skills

The installer also lands the following skill directly into
`<project>/.agents/skills/<name>/` — these live inside your project's git
history (no global `~/.agents/skills/` dependency). Claude Code sees the same
skill through `<project>/.claude/skills`, a symlink created by `install.sh`.

| Skill      | Where it lands                              | Purpose                                                                       |
|------------|---------------------------------------------|-------------------------------------------------------------------------------|
| `push2gh`  | `<project>/.agents/skills/push2gh/SKILL.md` | Commit → push → PR → optional automerge → cleanup. Use as a `gstack`-free substitute for `/ship` + `/land-and-deploy` in `WORKFLOW.md` phase 6. |

**Updating bundled skills.** Bundled skill bodies are **snapshots** taken
when the template was built. To pull a newer copy from your global skills
directory:

```bash
cp ~/.agents/skills/push2gh/SKILL.md \
   ~/projects/00.base-files/common/.agents/skills/push2gh/SKILL.md

cd ~/projects/00.base-files
git diff common/.agents/skills/push2gh/SKILL.md      # review the delta
git add common/.agents/skills/push2gh/SKILL.md
git commit -m "chore: refresh push2gh skill snapshot"
git push
```

Downstream projects pick up the new snapshot the next time they run
`install.sh --force`.

### Using superpowers in a fresh project

Once installed, Claude can invoke these skills automatically:

- "Let's brainstorm feature X" → `superpowers:brainstorming`
- "Write an implementation plan for X" → `superpowers:writing-plans`
- "Implement the plan at docs/superpowers/plans/..." → `superpowers:subagent-driven-development` or `superpowers:executing-plans`

The pipeline reminder injected by `.claude/settings.json` and `.codex/hooks.json` reinforces this
flow whenever you mention a feature-request keyword.

---

## 10. Re-running on an existing project

Two common reasons to re-run the installer:

### 10.1 Template was updated

When you pull a newer version of the template, re-run the installer in each
of your projects to pick up the new guidance:

```bash
cd ~/projects/00.base-files && git pull        # update the template
cd ~/projects/booklist                          # go back to your project
~/projects/00.base-files/install.sh --force     # re-run with --force
```

`--force` backs up every existing file with a `*.bak.YYYYMMDD-HHMMSS` suffix
and replaces it. You can `git diff` afterward to see what changed and decide
which changes to keep.

After the rerun, delete the `.bak.*` files once you've reviewed them:

```bash
find . -name '*.bak.[0-9]*' -print     # preview
find . -name '*.bak.[0-9]*' -delete    # delete
```

(`.bak.[0-9]*` is in the template's `.gitignore`, so backups don't
contaminate `git status`.)

### 10.2 Switching language

If a project starts as Python and pivots to Go:

```bash
cd ~/projects/data-pipeline

# Remove the Python overlay files manually (or git rm them)
git rm docs/standards/STACK.md docs/standards/TOOLS.md

# Add a Go module
go mod init github.com/myorg/data-pipeline

# Rerun the installer — it will detect go.mod and apply the Go overlay
~/projects/00.base-files/install.sh
```

The merged `.claude/settings.json` will be regenerated from scratch with the
Go-specific hooks (and the common ones).

### 10.3 Conflict resolution

Without `--force`, the installer prompts per file:

```
File exists: ./CLAUDE.md
  [o]verwrite (with backup) / [s]kip / [q]uit ?
```

- `o` — back up the existing file with a timestamp suffix, overwrite
- `s` — leave the existing file alone, do not write anything
- `q` — abort the whole installer; exit code 4

In CI or automation, always pass `--force` and use the timestamped backups
plus `git diff` to audit the changes.

---

## 11. Customizing for your team

The template is meant to be **forked, not configured**. There are no config
files; instead, you modify the source-of-truth files and commit.

### 11.1 Add a team-wide convention to RULES.md

Edit `~/projects/00.base-files/common/docs/standards/RULES.md`. Add your
team's convention as a new section. Commit and push:

```bash
cd ~/projects/00.base-files
$EDITOR common/docs/standards/RULES.md
git add common/docs/standards/RULES.md
git commit -m "docs(rules): add convention about <X>"
git push
```

Anyone re-running the installer in their project (with `--force`) picks up
the new convention.

### 11.2 Change the Rails linter from rubocop to standardrb

Two edits:

```bash
$EDITOR ~/projects/00.base-files/langs/rails/docs/standards/TOOLS.md   # docs
$EDITOR ~/projects/00.base-files/langs/rails/.claude/settings.json     # hook command
```

In `settings.json`, replace `bin/rubocop` with `bin/standardrb` in both the
pre-commit hook and the post-Write/Edit hook. Validate the JSON before
committing:

```bash
jq empty ~/projects/00.base-files/langs/rails/.claude/settings.json && echo OK
```

### 11.3 Add a default pre-commit hook for every language

If you want a hook to run regardless of language (e.g. secret scanning),
add it to `common/.claude/settings.json` under `PreToolUse`. The merge in
phase 4 will concatenate it with any language-specific hooks.

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
            "command": "git diff --cached | grep -qE 'AKIA[A-Z0-9]{16}' && echo '...' || true"
          }
        ]
      }
    ]
  }
}
```

### 11.4 Disable plugin installation by default

Edit `install.sh` and change `SKIP_SKILLS=0` to `SKIP_SKILLS=1`. The
`--skip-skills` flag is then a no-op (already-set), and users who want
plugins must pass an explicit `--install-skills` — which is not a real flag
yet, so you'd have to add it. Simpler: rename the flag instead.

---

## 12. Adding a new language overlay

Recommended next overlays, in order:

| Candidate | Detect by | Why add it |
|-----------|-----------|------------|
| `node` | `package.json` without `next` | Covers CLIs, libraries, Express/Fastify APIs, and general JavaScript/TypeScript projects. |
| `rust` | `Cargo.toml` | Excellent CLI/system-project fit with `cargo fmt`, `clippy`, and `test`. |
| `java-spring` | `pom.xml`, `build.gradle`, or `build.gradle.kts` | Common backend stack with Maven/Gradle conventions. |
| `dotnet` | `*.sln` or `*.csproj` | Common enterprise/API stack with `dotnet format` and `dotnet test`. |
| `php-laravel` | `composer.json` with `laravel/framework` | Common web-app stack with Pint/PHPStan/Pest or PHPUnit conventions. |
| `iac` | `*.tf`, `Chart.yaml`, `kustomization.yaml` | DevOps-heavy repos need Terraform/Helm/Kubernetes validation and secret scanning. |

Add a general `node` overlay next when non-Next JavaScript/TypeScript projects
become common.

To support Rust, Elixir, Crystal, or any other language:

### 12.1 Create the overlay directory

```bash
cd ~/projects/00.base-files
mkdir -p langs/<lang>/docs/standards langs/<lang>/.claude
```

### 12.2 Add the three required files

- `langs/<lang>/docs/standards/STACK.md` — framework choices, ORM,
  migrations, background jobs, caching, security guardrails (mirror the
  structure of `langs/python/docs/standards/STACK.md`).
- `langs/<lang>/docs/standards/TOOLS.md` — exact commands for tests,
  linters, type-checking, etc.
- `langs/<lang>/.claude/settings.json` — pre-commit hooks (test + lint
  gated on `Bash(git commit*)`) and a `PostToolUse` formatter on the file
  extension. Mirror the Python overlay structure; replace `pytest`/`ruff`
  with your language's equivalents.

Validate the JSON:

```bash
jq empty langs/<lang>/.claude/settings.json
```

### 12.3 Teach the detector

Edit `lib/detect-language.sh`, find the manifest-sniffing section, and add
a branch:

```bash
if [[ -f Cargo.toml ]]; then
  printf 'rust\n'; return 0
fi
```

Also update the `_BASE_FILES_LANGS` array at the top of the file so
`--lang rust` is accepted.

### 12.4 Add a test case

Edit `tests/test_detect_language.sh` and add a case for the new manifest:

```bash
mkdir "$TMP/rust-proj" && touch "$TMP/rust-proj/Cargo.toml"
r=$(detect_in "$TMP/rust-proj")
[[ "$r" == "rust" ]] || fail "Cargo.toml -> rust (got '$r')"
ok "Cargo.toml -> rust"
```

Re-run the test:

```bash
./tests/test_detect_language.sh
```

### 12.5 Add a smoke test

Create `tests/smoke_rust.sh` mirroring `tests/smoke_python.sh`. Then:

```bash
RUN_SMOKE=1 ./tests/run_all.sh
```

Confirm the pass count increases by one and `failed: 0`.

### 12.6 Update `check-deps.sh`

Add a default runtime list:

```bash
: "${REQUIRED_LANG_rust:=}"
[[ -z "${REQUIRED_LANG_rust:-}" ]] && REQUIRED_LANG_rust=(cargo)
```

…and a case branch in `check_deps()`:

```bash
case "$lang" in
  rails)  for t in "${REQUIRED_LANG_rails[@]}";  do all+=("$t"); done ;;
  python) for t in "${REQUIRED_LANG_python[@]}"; do all+=("$t"); done ;;
  go)     for t in "${REQUIRED_LANG_go[@]}";     do all+=("$t"); done ;;
  rust)   for t in "${REQUIRED_LANG_rust[@]}";   do all+=("$t"); done ;;
esac
```

Add an install hint to `_install_hint()`:

```bash
cargo)   echo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" ;;
```

### 12.7 Commit

```bash
git add langs/rust lib/detect-language.sh lib/check-deps.sh tests/
git commit -m "feat: add Rust language overlay"
git push
```

Anyone running the installer in a directory with a `Cargo.toml` now gets the
Rust overlay automatically.

---

## 13. Troubleshooting

### "claude CLI not found"

```
[WARN] claude CLI not found; skipping plugin installation. See https://docs.claude.com/claude-code
```

Phase 5 is skipped but the rest of the installer succeeds. Install Claude
Code (see https://docs.claude.com/claude-code), then re-run with
`--skip-skills=false` (which is the default — just re-run normally).

### "jq missing"

```
[WARN] jq missing — install with: sudo apt install -y jq        # or: brew install jq
```

The installer continues through phases 1–3 (file copy). Phase 4 fails
because `jq` is required for the merge. Install `jq` and rerun.

### Files were written to the wrong directory

Always **`cd` into the target project first**, then run the installer with
its absolute path. The installer uses `pwd` to find the target — not the
script's location.

```bash
# Wrong
~/projects/00.base-files/install.sh   # writes into wherever you are now

# Right
cd ~/projects/my-new-app
~/projects/00.base-files/install.sh
```

### Wrong language detected

Possible causes:

- The manifest file has a typo (e.g. `Gemfile.lock` only, no `Gemfile`).
- Multiple manifests exist (e.g. a `pyproject.toml` left over from a
  refactor in what is now a Go project).

Force the right one:

```bash
~/projects/00.base-files/install.sh --lang go
```

### File conflict prompt won't accept input

The installer may prompt when a destination file already exists. If you run it
under a shell that has no TTY (e.g. piped through another command), that prompt
can fail.

Fixes:

- Pass `--lang <x>` explicitly if you want to avoid relying on manifest
  detection or the default `bash` overlay.
- Pass `--force` to skip the per-file conflict prompt.
- Set `BASE_FILES_NONINTERACTIVE=1` in CI for clarity, but still use `--force`
  when existing files may be present.

### Merged `settings.json` is invalid

Phase 4 validates the merged JSON with `jq empty` before writing it.
If you see:

```
[ERROR] merged settings.json is invalid JSON
```

…either the common or the language-specific `settings.json` in the template
has been corrupted. Validate them individually:

```bash
jq empty ~/projects/00.base-files/common/.claude/settings.json
jq empty ~/projects/00.base-files/langs/<lang>/.claude/settings.json
```

Fix whichever fails, then re-run the installer.

### Pre-commit hook keeps failing on a Rails project

Common causes:

- `bin/rails` or `bin/rubocop` is not executable (`chmod +x bin/*`).
- `rbenv`/`asdf` shims are not on PATH. The hook prepends
  `$HOME/.rbenv/shims:$HOME/.rbenv/bin` to PATH; if you use `asdf`,
  edit `langs/rails/.claude/settings.json` and replace the rbenv path with
  `$HOME/.asdf/shims`.

### Permission denied when running `./install.sh`

```bash
chmod +x ~/projects/00.base-files/install.sh
```

This bit can get lost when the repo is unpacked from a tarball. Cloning via
`git` preserves it.

### Backups are piling up

Each `--force` run creates a new `*.bak.YYYYMMDD-HHMMSS`. To clean up old
backups in a project:

```bash
find . -name '*.bak.[0-9]*' -mtime +7 -delete    # older than 7 days
```

---

## 14. Testing the template itself

The template ships with a test suite that you run from the template root:

```bash
cd ~/projects/00.base-files

# Unit tests for every lib module (fast, hermetic)
./tests/run_all.sh
# → passed: 6 / failed: 0

# Unit + end-to-end smoke tests (driving the real installer in temp dirs)
RUN_SMOKE=1 ./tests/run_all.sh
# → passed: 16 / failed: 0
```

### What the tests cover

| Test file                          | Module                       | What it checks |
|------------------------------------|------------------------------|-----------------|
| `tests/test_log.sh`                | `lib/log.sh`                 | Each log function prefix; NO_COLOR contract; stderr routing of `log_warn`/`log_error` |
| `tests/test_detect_language.sh`    | `lib/detect-language.sh`     | Rails/Python/Go/Next.js manifests detected; empty projects default to Bash; `--lang` override beats detection; invalid override → exit 2 |
| `tests/test_check_deps.sh`         | `lib/check-deps.sh`          | Real deps not falsely missing; injected fake dep is recorded in `MISSING_DEPS` |
| `tests/test_copy_files.sh`         | `lib/copy-files.sh`          | Fresh copy; conflict overwrites with backup; dry-run writes nothing |
| `tests/test_merge_settings.sh`     | `lib/merge-settings.sh`      | Hook arrays concatenated; dry-run is read-only; missing input fails |
| `tests/test_install_skills.sh`     | `lib/install-skills.sh`      | Idempotent (already-present items skipped); dry-run never calls `claude plugin install`; uses a fake `claude` binary on PATH for hermetic test |
| `tests/smoke_rails.sh`             | end-to-end                   | `Gemfile` triggers rails overlay; dry-run writes nothing; real run lands files + ≥2 PreToolUse hooks |
| `tests/smoke_python.sh`            | end-to-end                   | `pyproject.toml` triggers python overlay; PostToolUse references `ruff` |
| `tests/smoke_go.sh`                | end-to-end                   | `go.mod` triggers go overlay; PostToolUse references `gofmt` |
| `tests/smoke_nextjs.sh`            | end-to-end                   | Next.js `package.json` triggers nextjs overlay; PostToolUse references `prettier`/`eslint` |
| `tests/smoke_empty.sh`             | end-to-end                   | Empty dir defaults to the bash overlay; shared agent files and bootstrap commit work |

### Adding a new test

Tests follow a simple convention:

```bash
#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$ROOT/lib/log.sh"
source "$ROOT/lib/<module>.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# Tests here ...

echo "test_<module>.sh: ALL PASS"
```

Make it executable with `chmod +x`. The top-level `tests/run_all.sh`
auto-discovers any `tests/test_*.sh` file.

For end-to-end smoke tests, use the prefix `smoke_*.sh` — they run only
when `RUN_SMOKE=1` is set, since they're slower.

---

## 15. Repository layout

```
.
├── install.sh                       # 5-phase entry point (parses flags, runs phases)
├── README.md                        # one-page quick start
├── VERSION                          # template version (semver)
├── .gitignore                       # excludes *.bak.* backups, editor/test noise
│
├── common/                          # language-neutral, applied to every project
│   ├── CLAUDE.md                    # global guidance
│   ├── docs/standards/
│   │   ├── RULES.md                 # DRY, Tidy First, AI-writing
│   │   ├── WORKFLOW.md              # six-phase pipeline
│   │   ├── QUALITY.md               # test, security, accessibility, perf principles
│   │   └── REVIEW.md                # code-review checklist
│   └── .claude/
│       ├── settings.json            # graphify reminder + pipeline reminder
│       └── hooks/pipeline-reminder.txt
│
├── langs/                           # per-language overlays (one applied per install)
│   ├── rails/
│   │   ├── docs/standards/{STACK.md, TOOLS.md}
│   │   └── .claude/settings.json    # rails test + rubocop pre-commit; .rb auto-rubocop
│   ├── python/
│   │   ├── docs/standards/{STACK.md, TOOLS.md}
│   │   └── .claude/settings.json    # pytest + ruff; .py auto-ruff
│   └── go/
│       ├── docs/standards/{STACK.md, TOOLS.md}
│       └── .claude/settings.json    # go test + golangci-lint; .go auto-gofmt+vet
│
├── lib/                             # installer internals (sourced bash modules)
│   ├── log.sh                       # color logger (NO_COLOR aware)
│   ├── detect-language.sh           # manifest sniffer + bash fallback
│   ├── check-deps.sh                # OS-tool presence probe (report-only)
│   ├── copy-files.sh                # tree copy with timestamped backup + dry-run
│   ├── merge-settings.sh            # jq deep-merge with validation
│   └── install-skills.sh            # idempotent claude plugin orchestration
│
├── tests/                           # hermetic test suite
│   ├── run_all.sh                   # top-level runner (RUN_SMOKE=1 gates smoke)
│   ├── test_*.sh                    # 6 unit tests, one per lib module
│   └── smoke_*.sh                   # 4 end-to-end scenarios
│
└── docs/
    ├── USAGE.md                     # this document
    └── superpowers/
        ├── specs/2026-05-21-...     # design spec for the template itself
        └── plans/2026-05-21-...     # implementation plan for the template itself
```

---

## 16. Design rationale

### Why "common + overlay" instead of "templated single file"?

A single template file with placeholders (`{{LINT_COMMAND}}`,
`{{TEST_COMMAND}}`, etc.) would be smaller, but every reader who opens the
file sees template markers instead of real content. The split lets Claude
read the language-specific `STACK.md` directly without interpreting
placeholders, and lets a human (or AI) skim the common rules without
visual noise from language switches.

### Why a bash installer instead of a Python or Go binary?

Three reasons:

1. **No build step.** A single `git clone` is enough to use the template.
2. **No new runtime dependency.** Bash + `jq` + `git` are already present
   anywhere we'd install this.
3. **The installer's job is gluing tools together** (`jq`, `find`, `cp`,
   `claude plugin`). Bash is purpose-built for this; a higher-level language
   would just wrap the same shell commands with more ceremony.

### Why does the installer never auto-install OS tools?

Two practical reasons:

1. **It would have to detect the package manager** (apt/dnf/yum/pacman/brew)
   and might need `sudo`. That's a lot of code with security implications.
2. **It risks breaking the user's existing setup.** Many developers manage
   languages with `asdf` or `pyenv` or `rbenv`; installing `python3` via
   `apt` could shadow or conflict with the existing managed runtime.

Reporting missing tools surfaces the problem without taking irreversible
action. The hint message gives the exact command to install — the developer
runs it in the context they trust.

### Why does the installer NOT auto-install OS tools, but DOES auto-install Claude plugins?

The user explicitly opted into Claude plugin installation when accepting the
auto-install design decision. Plugin installation is **per-user** (under
`~/.claude/`), reversible (`claude plugin uninstall <x>`), and uses the
official `claude plugin` CLI — none of which carry the risks of OS-level
package installation.

`--skip-skills` is provided as an escape hatch for users who manage plugins
manually or run in CI.

### Why is RULES.md separate from CLAUDE.md?

`CLAUDE.md` is the entry-point Claude reads at session start; it stays
short. `RULES.md` is the deeper reference — DRY, Tidy First, documentation
rules, AI-writing guidelines — that's worth reading once but not on every
session. `CLAUDE.md` links to it.

### Why six phases in the workflow, not three?

See `common/docs/standards/WORKFLOW.md` for the full breakdown. The short
version: separating product discovery (phase 1, gstack) from system
architecture (phase 2) from technical design (phase 3, superpowers) from
task breakdown (phase 4) catches different classes of mistakes at the right
moment. Phases can be skipped explicitly for small tweaks; the
`UserPromptSubmit` hook reminds you only when a feature-request keyword
appears.

---

## Further reading

- The original design spec: [`docs/superpowers/specs/2026-05-21-multi-language-base-template-design.md`](superpowers/specs/2026-05-21-multi-language-base-template-design.md)
- The implementation plan: [`docs/superpowers/plans/2026-05-21-multi-language-base-template.md`](superpowers/plans/2026-05-21-multi-language-base-template.md)
- README: [`../README.md`](../README.md)
