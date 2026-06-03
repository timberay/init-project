# base-files

Multi-language base template for new projects. One command installs common
guidance, language-specific tooling, an ADR-backed orchestrator, and
recommended Claude Code plugins into a fresh project directory.

Supported overlays: **Rails 8 · Python (FastAPI/Django) · Go · Bash/Shell**.

> One-page quick start below. For the full reference (every flag, every
> phase, walkthroughs per language, troubleshooting, and how to add a new
> language overlay), see [`docs/USAGE.md`](docs/USAGE.md).

---

## Quick start

**Prerequisites** (machine-level, install once):

| Tool         | Why                              | Install                                                |
|--------------|----------------------------------|--------------------------------------------------------|
| `git`        | source control                   | `apt install git` · `brew install git`                 |
| `jq`         | merges `.claude/settings.json`   | `apt install jq` · `brew install jq`                   |
| `pre-commit` | runs commit-time quality gates   | `pipx install pre-commit` · `uv tool install pre-commit` |
| Claude CLI   | installs the recommended plugins | <https://docs.claude.com/en/docs/claude-code>          |

Each language overlay also needs its own toolchain: Ruby + Bundler + Rails
for `rails`, `uv` (or `pip`) for `python`, `go` 1.22+ for `go`, and Bash
plus optional `shellcheck`/`shfmt` for `bash`.

**Bootstrap a new project** (Rails shown — Python / Go / Bash differ only in
step 2):

```bash
# 1. Get this template once (anywhere on disk; examples assume ~/projects/init-project)
git clone https://github.com/timberay/init-project ~/projects/init-project

# 2. Create the new project and initialize the framework
mkdir -p ~/projects/my-app && cd ~/projects/my-app
rails new . --minimal                  # Rails
# or:  uv init                         # Python
# or:  go mod init example.com/my-app  # Go
# or:  touch scripts/bootstrap.sh       # Bash/Shell, or leave empty

# 3. Drop the overlay on top
~/projects/init-project/install.sh

# 4. Wire up git + pre-commit hooks
git init
pre-commit install
git add . && git commit -m "Bootstrap from base-files"
```

That's it. Your new project now has `CLAUDE.md` guidance, language-specific
linters, the PROJECT_STATE + ADR + Hooks orchestrator, pre-commit + CI
quality gates ([ADR-0001](docs/decisions/ADR-0001-quality-gates-owned-by-precommit.md)),
a `PROJECT_STATE.md` seeded to the `Setup` lifecycle stage ([ADR-0003](docs/decisions/ADR-0003-adopt-lifecycle-stages.md)),
and the recommended Claude Code plugins.

**Rails note ([ADR-0002](docs/decisions/ADR-0002-rails-rubocop-tolerant-of-missing-gem.md)):**
the rubocop pre-commit hook is a graceful no-op until rubocop is in your
bundle. To actually run it, add `gem "rubocop-rails-omakase"` (or your
preferred rubocop gem) to your Gemfile and `bundle install` before
committing. `rails new --minimal` omits it by default.

---

## What `install.sh` does

1. **Detects the language** from `Gemfile` / `pyproject.toml` (or
   `requirements.txt`, `Pipfile`) / `go.mod`. Empty or unrecognized projects
   default to the `bash` overlay. Override with `--lang <x>`.
2. **Verifies OS tools** (`jq`, `git`, language runtime). Missing tools
   are **reported**, never auto-installed.
3. **Copies files** — `common/` + the matching `langs/<lang>/` into the
   current directory. Existing files are backed up as
   `<name>.bak.YYYYMMDD-HHMMSS` before being overwritten (with `--force`).
4. **Deep-merges** `common/.claude/settings.json` with the language
   overlay's `settings.json` into `.claude/settings.json`, validating
   the result with `jq`.
5. **Creates agent compatibility links** so Claude Code reads the project
   skills from the same `.agents/skills` directory that Codex scans natively.
6. **Installs recommended Claude Code plugins** via `claude plugin`.
   Skipped with `--skip-skills`.

### Options

| Flag             | Purpose                                                           |
|------------------|-------------------------------------------------------------------|
| `--lang <x>`     | Override auto-detection (`rails`, `python`, `go`, `bash`)         |
| `--dry-run`      | Print the plan; do not write files or invoke `claude plugin`      |
| `--force`        | Overwrite existing files (backed up with `*.bak.YYYYMMDD-HHMMSS`) |
| `--skip-skills`  | Skip plugin installation entirely                                 |
| `-h`, `--help`   | Show usage                                                        |

Common combinations:

```bash
~/projects/init-project/install.sh --dry-run            # preview only
~/projects/init-project/install.sh --lang python --force  # override detection
~/projects/init-project/install.sh --lang bash          # force shell overlay
~/projects/init-project/install.sh --skip-skills        # offline / no Claude CLI
```

### Recommended future overlays

The current overlays cover Rails, Python, Go, and shell-first projects. Good
next candidates:

| Candidate | Detect by | Why add it |
|-----------|-----------|------------|
| `nextjs` / `typescript` | `package.json` with `next`, `next.config.*`, `tsconfig.json` | Most useful next web-app overlay: TypeScript/React/Next.js projects need ESLint, type-check, test, and build gates. |
| `node` | `package.json` without `next` | Covers CLIs, libraries, Express/Fastify APIs, and general JavaScript/TypeScript tooling. |
| `rust` | `Cargo.toml` | Strong fit for CLI/system projects with deterministic `cargo fmt`, `clippy`, and `test` commands. |
| `java-spring` | `pom.xml`, `build.gradle`, or `build.gradle.kts` | Common backend stack; needs Maven/Gradle test and formatting conventions. |
| `dotnet` | `*.sln` or `*.csproj` | Common enterprise/API stack with clear `dotnet test` and formatting gates. |
| `php-laravel` | `composer.json` with `laravel/framework` | Common web-app stack with Pint/PHPStan/Pest or PHPUnit conventions. |
| `iac` | `*.tf`, `Chart.yaml`, `kustomization.yaml` | DevOps-heavy repos need Terraform/Helm/Kubernetes validation and stricter secret checks. |

Recommended order: add `nextjs` first, then split a more general `node`
overlay if non-Next JavaScript projects become common.

---

## AI tool setup

`install.sh` builds a project-local AI development environment for Claude Code,
Codex, and opencode. It does not rewrite your personal global config by
default; the generated files live in the target project.

### Shared foundation

Every supported AI tool starts from the same project state, decisions, and
quality gates:

```text
PROJECT_STATE.md
docs/decisions/
docs/standards/
.agent-hooks/
.agents/skills/
.pre-commit-config.yaml
.github/workflows/ci.yml
```

- `PROJECT_STATE.md` records the current lifecycle stage, active work, and
  open questions.
- `docs/decisions/` stores ADRs. Accepted ADRs are append-only; reverse them
  with a superseding ADR.
- `docs/standards/` contains the development rules, workflow, review checklist,
  quality policy, stack notes, and tool commands.
- `.agent-hooks/` contains the shared hook scripts used by Claude Code and
  Codex.
- `.agents/skills/` is the project skill source of truth.
- `.pre-commit-config.yaml` and `.github/workflows/ci.yml` are the real
  enforcement layer, independent of which AI tool wrote the code.

### Claude Code

Claude Code is initialized with:

```text
CLAUDE.md
.claude/settings.json
.claude/commands/
.claude/skills -> ../.agents/skills
```

`CLAUDE.md` is Claude Code's project instruction file. It tells Claude to read
`PROJECT_STATE.md`, consult ADRs before changing prior decisions, follow TDD,
keep refactors separate from behavior changes, and use the standards docs for
task-specific rules.

`.claude/settings.json` wires Claude Code hook events to the shared scripts:

```text
SessionStart      -> .agent-hooks/sessionstart-inject-state.sh
UserPromptSubmit  -> .agent-hooks/userpromptsubmit-pipeline.sh
UserPromptSubmit  -> .agent-hooks/userpromptsubmit-remind.sh
PreToolUse Bash   -> .agent-hooks/security-check.sh
PreToolUse edits  -> .agent-hooks/pretooluse-stale-check.sh
```

`.claude/commands/` installs the orchestrator slash commands:

```text
/decide
/state-sync
/supersede ADR-NNNN
```

`.claude/skills` is a symlink to `../.agents/skills`, so Claude Code sees the
same project skills as Codex.

### Codex

Codex is initialized with:

```text
AGENTS.md
.codex/config.toml
.codex/hooks.json
.agents/skills/
```

`AGENTS.md` is Codex's durable project guidance. It keeps the shared policy
short: Korean conversation, English code/docs/commits, TDD, relevant checks,
ADR discipline, pre-commit/CI as enforcement, and separate worktrees when
running multiple coding agents in parallel.

`.agents/skills/` is the native Codex skill location. The bundled `push2gh`
skill lands at:

```text
.agents/skills/push2gh/SKILL.md
```

`.codex/hooks.json` calls the same `.agent-hooks` scripts as Claude Code for
session context, pipeline reminders, ADR reminders, stale state warnings, and
Bash safety checks. Current Codex releases enable hooks by default; project
hooks may still need review/trust when Codex first opens the repository.

### opencode

opencode is initialized with:

```text
AGENTS.md
opencode.json
```

`opencode.json` points opencode at `AGENTS.md` plus the standards docs:

```text
docs/standards/RULES.md
docs/standards/QUALITY.md
docs/standards/WORKFLOW.md
docs/standards/REVIEW.md
docs/standards/LIFECYCLE.md
docs/standards/STACK.md
docs/standards/TOOLS.md
```

The default permission posture is conservative:

- edits require approval
- Bash commands require approval by default
- read-only exploration commands such as `git status`, `git diff`, `rg`, `ls`,
  and `find` are allowed
- external directory access requires approval

### Runtime flow

After installation, the tools line up like this:

```text
Claude Code
  reads: CLAUDE.md
  hooks: .claude/settings.json -> .agent-hooks/*
  skills: .claude/skills -> .agents/skills
  commands: .claude/commands/*

Codex
  reads: AGENTS.md
  hooks: .codex/hooks.json -> .agent-hooks/*
  skills: .agents/skills
  config: .codex/config.toml

opencode
  reads: AGENTS.md + docs/standards/*
  config: opencode.json
  permissions: ask-by-default

All tools
  state: PROJECT_STATE.md
  decisions: docs/decisions/*
  standards: docs/standards/*
  enforcement: pre-commit + CI
```

Agent hooks are guardrails, not the final security boundary. The actual merge
gate is still `pre-commit` plus CI, so the same checks apply no matter which AI
tool produced the change.

---

## What gets installed

```text
<project>/
├── CLAUDE.md                              (common — required reading every session)
├── PROJECT_STATE.md                       (common — orchestrator state, 100-line cap)
├── .editorconfig                          (common)
├── .gitignore                             (language overlay)
├── .pre-commit-config.yaml                (language overlay — commit-time fast checks, ADR-0001)
├── .github/
│   └── workflows/
│       └── ci.yml                         (language overlay — pre-commit + tests on PR / push to main)
├── docs/
│   ├── decisions/                         (common — append-only ADR log)
│   │   ├── README.md
│   │   └── ADR-0000-orchestrator-bootstrap.md
│   └── standards/
│       ├── RULES.md                       (common)
│       ├── WORKFLOW.md                    (common — six-phase pipeline)
│       ├── QUALITY.md                     (common — testing / security principles)
│       ├── REVIEW.md                      (common — code review checklist)
│       ├── LIFECYCLE.md                   (common — project lifecycle stages)
│       ├── STACK.md                       (language overlay — framework patterns)
│       └── TOOLS.md                       (language overlay — lint / test / security commands)
├── AGENTS.md                              (common — Codex/opencode guidance)
├── opencode.json                          (common — opencode instructions + permissions)
├── .codex/
│   ├── config.toml                        (common — project-scoped Codex defaults)
│   └── hooks.json                         (common — Codex hooks calling .agent-hooks)
├── .agent-hooks/                          (common — shared hook logic)
│   ├── sessionstart-inject-state.sh       (injects STATE + ADR index at session start)
│   ├── userpromptsubmit-remind.sh         (reminds agents to consult ADRs)
│   ├── userpromptsubmit-pipeline.sh       (six-phase reminder trigger)
│   ├── pretooluse-stale-check.sh          (warns when PROJECT_STATE.md is >7 days old)
│   ├── security-check.sh                  (blocks obvious destructive/prod Bash commands)
│   └── pipeline-reminder.txt              (six-phase reminder text)
├── .agents/
│   └── skills/
│       └── push2gh/SKILL.md               (common — bundled commit → push → PR skill)
└── .claude/
    ├── settings.json                      (common hooks + language hooks, deep-merged)
    ├── commands/                          (common — orchestrator slash commands)
    │   ├── decide.md                      (/decide — draft a new ADR)
    │   ├── state-sync.md                  (/state-sync — refresh PROJECT_STATE.md)
    │   └── supersede.md                   (/supersede ADR-NNNN — reverse a decision)
    └── skills -> ../.agents/skills        (Claude compatibility symlink)
```

---

## Recommended Claude Code plugins (auto-installed)

| Plugin                    | Marketplace                               | Purpose                                  |
|---------------------------|-------------------------------------------|------------------------------------------|
| `superpowers`             | `anthropics/claude-plugins-official`      | Brainstorm / plan / TDD / debug / review |
| `code-review`             | `anthropics/claude-plugins-official`      | Branch / PR review                       |
| `andrej-karpathy-skills`  | `forrestchang/andrej-karpathy-skills`     | Karpathy coding guardrails               |

`graphify` and `gstack` are **verified** (not installed) by the installer —
both live outside the claude plugin marketplaces. `gstack` is referenced by
`WORKFLOW.md` phases 1, 2, and 6; install it manually if you want the full
pipeline. Without it, those phases need manual substitutes — `push2gh`
below is the bundled phase-6 substitute.

### Bundled project skills

The installer copies these straight into `<project>/.agents/skills/<name>/`
and creates `<project>/.claude/skills -> ../.agents/skills` for Claude Code
compatibility, so they live inside the project's own git history
(independent of the user's global skill install):

| Skill      | Purpose                                                                                  |
|------------|------------------------------------------------------------------------------------------|
| `push2gh`  | Commit → push → PR → optional automerge → cleanup. `gstack`-free phase-6 substitute.     |

Bundled skills are snapshots committed into this template. Resync procedure
is in [`docs/USAGE.md`](docs/USAGE.md).

---

## Working with the orchestrator (PROJECT_STATE + ADR)

Two files are required reading at the start of every session. The
`SessionStart` hook injects them automatically:

- **`PROJECT_STATE.md`** — current phase, active work, locked decisions,
  open questions. Mutable. Refresh with `/state-sync` at phase transitions.
- **`docs/decisions/`** — append-only ADR log. `Accepted` ADRs are
  immutable; reverse with `/supersede ADR-NNNN`.

Slash commands available from any session inside a project bootstrapped
with base-files:

```text
/decide              # draft a new ADR from the current conversation
/state-sync          # propose a PROJECT_STATE.md diff and ask before saving
/supersede ADR-NNNN  # create a new ADR that reverses a previously Accepted one
```

See [`common/CLAUDE.md`](common/CLAUDE.md) for the full session-time rules.

---

## Hacking on this template

```bash
./tests/run_all.sh                     # unit tests only (fast, no toolchain needed)
RUN_SMOKE=1 ./tests/run_all.sh         # + dry-runs install.sh against fixture dirs
RUN_E2E=1 ./tests/run_all.sh           # + end-to-end against real frameworks
```

Each lib module has a focused test under `tests/`:

- `tests/test_*.sh` — unit tests for `lib/*.sh`, settings merge, hooks, yaml shape.
- `tests/smoke_*.sh` — drive `install.sh` against empty directories with only
  a manifest file present. Fast; no toolchain needed beyond `jq` + `git`.
- `tests/e2e_*.sh` — drive `install.sh` against a real `rails new` / `uv init` /
  `go mod init` sandbox, then run `pre-commit install` + first commit and verify
  the ADR-0001 bootstrap-commit invariant holds. Requires the matching
  toolchain + `pre-commit`.

E2E environment variables:

| Variable          | Effect                                                        |
|-------------------|---------------------------------------------------------------|
| `STRICT=1`        | Promote SKIP (missing toolchain) to FAIL.                     |
| `KEEP_SANDBOX=1`  | Do not delete the `/tmp/init-project-e2e-*` dir after the run. |

---

## Troubleshooting

- **"claude CLI not found"** — install Claude Code first; the installer falls
  through with a warning and your files are still placed. Re-run later
  without `--skip-skills` to install the plugins.
- **"jq missing"** — the installer will still copy files but `merge-settings`
  will fail. Install `jq` (`brew install jq` or `apt install jq`).
- **"pre-commit not found"** — `pipx install pre-commit` or
  `uv tool install pre-commit`. Required for the ADR-0001 commit-time gates.
- **Conflict resolution stuck** — re-run with `--force` to bypass per-file
  prompts; existing files are still backed up.
- **Wrong language detected** — re-run with `--lang <correct>`.
- **First commit fails right after `install.sh`** — a pre-commit hook
  (usually `trim-trailing-whitespace` or `end-of-file-fixer`) probably
  auto-fixed a file. The output above the error tells you which hook
  touched which file. Re-stage and retry:
  ```bash
  git add -u && git commit -m "Bootstrap from base-files"
  ```
- **Rails: "can't find executable rubocop"** — you have a Gemfile entry but
  no `bundle install`. Run `bundle install` and retry. If you don't want
  rubocop at all, the hook is already a no-op without the gem
  ([ADR-0002](docs/decisions/ADR-0002-rails-rubocop-tolerant-of-missing-gem.md)).
- **PROJECT_STATE drift warning at edit time** — `PROJECT_STATE.md` is more
  than 7 days old. Run `/state-sync` to refresh.
- **`install.sh --force` reset the Lifecycle Stage to `Setup`** — `--force`
  overwrites `PROJECT_STATE.md` with the template, re-seeding
  `> Lifecycle Stage:` to `Setup (since <today>)`. The previous file is
  preserved as `PROJECT_STATE.md.bak.YYYYMMDD-HHMMSS` in the same directory.
  To recover the prior stage value, copy the `> Lifecycle Stage:` line
  from the `.bak` file back into `PROJECT_STATE.md` and delete the backup
  when satisfied.
