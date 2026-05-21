# Multi-Language Base Template — Design Spec

- **Date:** 2026-05-21
- **Status:** Draft → awaiting user review
- **Repo:** `~/projects/00.base-files/`
- **Target users:** Single-developer workflow today (Ruby on Rails primarily; Python and Go secondary). Designed so the same template can be used unchanged across all three.

---

## 1. Problem & Goals

The current `00.base-files/` template is effectively Rails-only:

- `CLAUDE.md`, `docs/standards/RULES.md`, `QUALITY.md`, `STACK.md`, `TOOLS.md` all reference Rails 8, Rubocop, Minitest, TailwindCSS, Solid Queue, etc.
- `.claude/settings.json` hooks invoke `bin/rails test` and `bin/rubocop` and react to `.rb` files.

When the same developer starts a Python or Go project, none of this applies cleanly. The goal is:

1. Reorganize the template so **language-agnostic guidance lives in one place** and **language-specific guidance lives in interchangeable overlays**.
2. Ship an `install.sh` that, given a target project directory, bootstraps the right combination of common core + one language overlay — including hook configuration and recommended Claude Code skills — with a single command.

### Success criteria

- A new Rails / Python / Go project receives a working `CLAUDE.md`, `docs/standards/`, and `.claude/settings.json` in one command.
- The same `00.base-files/` repo serves all three languages without duplication of common rules.
- Recommended Claude Code skills (`superpowers`, `code-review`, `andrej-karpathy-skills`) are installed automatically; `graphify` presence is verified.
- Re-running the installer on an existing target is safe (backs up existing files; skips already-installed plugins).

---

## 2. Non-Goals

- **Project scaffolding** (e.g. running `rails new`, `uv init`, `go mod init`). The installer only places guidance/hooks; the user runs framework bootstrappers.
- **OS-level installation** of language runtimes (Ruby/Python/Go) or general CLI tools (`jq`, `gh`). Missing tools are reported, not installed.
- **Multi-language overlays in one project** (e.g. a Rails app that also has a Python data-pipeline). Out of scope for v1; a project gets exactly one overlay.
- **Migrating existing in-flight projects.** v1 targets new project bootstrap. A `--force` flag is provided for re-bootstrap, but conflict resolution beyond timestamped backup is not handled.

---

## 3. Locked-in Design Decisions

| # | Decision | Value | Rationale |
|---|---------|-------|-----------|
| 1 | Guidance layout | Common core (`common/`) + per-language overlays (`langs/<lang>/`) | Keeps shared principles in one place; isolates language-specific tooling. Adding a new language is purely additive. |
| 2 | Install scenario | New-project directory remotely calls `~/projects/00.base-files/install.sh` | Source-of-truth (`00.base-files/`) is never mutated. Target project owns its copy. |
| 3 | Language detection | Auto-detect by manifest file (`Gemfile`, `pyproject.toml`/`requirements.txt`/`Pipfile`, `go.mod`) with `--lang` override | Minimizes prompts in the happy path; explicit control when needed. |
| 4 | OS dependency handling | Check + report only; never auto-install | Avoids breaking the user's existing pyenv/rbenv/asdf setup. Surfaces missing tools as actionable hints. |
| 5 | Skill auto-install | `claude plugin marketplace add` + `claude plugin install` for the 3 recommended plugins; verify-only for `graphify` | The user explicitly requested automatic skill setup. Uses the official Claude Code CLI so behavior matches manual install. |

---

## 4. Source-of-Truth Folder Layout

```text
~/projects/00.base-files/
├── install.sh                   # Entry point, ≤ ~80 lines; delegates to lib/
├── README.md                    # Usage, flags, troubleshooting
├── VERSION                      # Semantic version of the template itself
│
├── common/                      # Copied verbatim into every target
│   ├── CLAUDE.md                # Language-neutral global guidance
│   ├── docs/standards/
│   │   ├── RULES.md             # DRY, Tidy First, AI-instruction-writing
│   │   ├── WORKFLOW.md          # Six-phase pipeline (already language-neutral)
│   │   ├── QUALITY.md           # Principles only — no tool names
│   │   └── REVIEW.md            # Manual code-review checklist
│   └── .claude/
│       ├── settings.json        # graphify reminder + pipeline reminder hooks only
│       └── hooks/
│           └── pipeline-reminder.txt
│
├── langs/                       # Exactly one overlay applied per install
│   ├── rails/
│   │   ├── docs/standards/
│   │   │   ├── STACK.md         # Rails 8 / TailwindCSS / Solid Queue / Solid Cache / etc.
│   │   │   └── TOOLS.md         # bin/rails, bin/rubocop, bin/brakeman, bin/bundler-audit
│   │   └── .claude/
│   │       └── settings.json    # pre-commit: rails test + rubocop; PostToolUse: .rb auto-rubocop
│   ├── python/
│   │   ├── docs/standards/
│   │   │   ├── STACK.md         # Django/FastAPI choice, uv/poetry, ORM/migration patterns
│   │   │   └── TOOLS.md         # ruff, pytest, mypy, pip-audit
│   │   └── .claude/
│   │       └── settings.json    # pre-commit: pytest + ruff; PostToolUse: .py auto-ruff-format
│   └── go/
│       ├── docs/standards/
│       │   ├── STACK.md         # Standard layout, net/http vs chi/echo, go modules
│       │   └── TOOLS.md         # gofmt, go vet, golangci-lint, govulncheck, go test
│       └── .claude/
│           └── settings.json    # pre-commit: go test + golangci-lint; PostToolUse: .go auto-gofmt
│
└── lib/                         # install.sh internals (bash modules)
    ├── log.sh                   # Color logger: info / ok / warn / error / action / section
    ├── detect-language.sh       # Manifest sniffing + interactive fallback
    ├── check-deps.sh            # OS tool presence checks (no install)
    ├── copy-files.sh            # Copy common/ + langs/<x>/ into cwd with timestamped backups
    ├── merge-settings.sh        # jq deep-merge of two settings.json files
    └── install-skills.sh        # claude plugin marketplace/install orchestration
```

### What "common" excludes

`STACK.md` and `TOOLS.md` are deliberately **not** in `common/`. Their contents are always framework-bound, so attempting a language-neutral version would either be empty or misleading. They live only in overlays.

### What `common/QUALITY.md` looks like (excerpt)

Tool names are removed; principles remain:

- Testing: test pyramid, regression-test-required-for-bugfix.
- Security: "no secrets in git", "input validation at boundaries", "least privilege", "rate-limit public endpoints", "output encoding for user content".
- Performance: "measure before caching", "no N+1", "off-request work for heavy I/O", "index filter/sort columns".
- Accessibility: full current section retained (already framework-neutral).
- Evidence-driven self-diagnosis: retained.
- Pre-commit failure recovery: keeps the workflow rule ("fix and retry, do not stop") but defers exact commands to `TOOLS.md`.

Framework-specific guidance (CSRF, `params.expect`, Rack::Attack, ReDoS guard, axe-core-capybara, fragment caching, Bullet gem) moves into `langs/rails/STACK.md`.

---

## 5. Installer Design

### 5.1 Entry-point flow (`install.sh`)

Five sequential phases, each delegated to a `lib/` module:

1. **Detect language** — `detect-language.sh`. Reads manifest files in the target directory; falls back to interactive `select` if ambiguous; honors `--lang` override.
2. **Check OS dependencies** — `check-deps.sh`. Verifies `jq`, `git`, `gh`, and the language runtime. Missing items logged with install hint; never blocks.
3. **Copy files** — `copy-files.sh`. Copies `common/*` then `langs/<detected>/*` into `cwd`. If a destination file already exists, the installer pauses and asks the user whether to back-up-then-overwrite or skip (per file). `--force` bypasses the prompt and always backs-up-then-overwrites. Backup name format: `<file>.bak.YYYYMMDD-HHMMSS`.
4. **Merge settings** — `merge-settings.sh`. Deep-merges `common/.claude/settings.json` with the language overlay's `settings.json` via `jq` (array concatenation for `hooks.*`), writes to `cwd/.claude/settings.json`. Validates the result with `jq empty`.
5. **Install skills** — `install-skills.sh`. Adds marketplaces and installs plugins (see §6). Skipped when `--skip-skills` is set.

After phase 5 a summary is printed: files created, files backed up, plugins newly installed, plugins already present, missing OS tools, and the next suggested step (`git init && git add . && git commit -m "Bootstrap from base-files"`).

### 5.2 Flags

| Flag | Behavior |
|------|----------|
| `--lang <rails\|python\|go>` | Override auto-detection. |
| `--dry-run` | Print the plan without copying files, mutating settings, or calling `claude plugin`. |
| `--force` | Bypass the per-file overwrite prompt. Each existing file is backed up once with timestamp suffix and then overwritten. |
| `--skip-skills` | Skip phase 5 entirely. Useful in CI or when `claude` CLI is absent. |
| `-h` / `--help` | Print usage and exit. |

### 5.3 Idempotency & safety

- **Detection is read-only.** Phase 1 never writes.
- **Backups before overwrite.** Existing `CLAUDE.md`, `docs/standards/*`, and `.claude/settings.json` are renamed with a timestamp suffix the first time the installer touches them in a run.
- **`set -uo pipefail` but not `-e`.** Individual phase failures are caught and reported in the final summary; one missing plugin does not abort the whole run.
- **Plugin installs are idempotent.** `ensure_marketplace` and `ensure_plugin` short-circuit if the target is already registered (checked via `claude plugin marketplace list` and `claude plugin list`).
- **JSON sanity check.** After `merge-settings.sh` writes the merged file, `jq empty` runs against it; failure prevents the merged file from replacing the original.
- **No global writes outside `~/.claude/` plugin areas.** The installer never touches the user's global `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, or shell rc files.

### 5.4 Detection details (`detect-language.sh`)

```text
priority order (first match wins):
  Gemfile or *.gemspec                        → rails
  pyproject.toml or requirements.txt or Pipfile → python
  go.mod                                       → go
  (none)                                       → interactive select
```

`--lang <x>` overrides any detection result and skips the interactive prompt.

### 5.5 Settings merge (`merge-settings.sh`)

The two `settings.json` files use the same shape: `{ "hooks": { "PreToolUse": [...], "PostToolUse": [...], "UserPromptSubmit": [...] } }`. The merge concatenates the arrays for each hook event:

```bash
jq -s '
  reduce .[] as $x (
    {hooks:{}};
    .hooks.PreToolUse       = ((.hooks.PreToolUse       // []) + ($x.hooks.PreToolUse       // [])) |
    .hooks.PostToolUse      = ((.hooks.PostToolUse      // []) + ($x.hooks.PostToolUse      // [])) |
    .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + ($x.hooks.UserPromptSubmit // []))
  )
' "$common" "$lang" > "$tmp" && jq empty "$tmp" && mv "$tmp" "$target"
```

Result: every target gets the language-neutral hooks (graphify reminder, pipeline reminder) plus the language-specific hooks (pre-commit test/lint, PostToolUse formatter), in that order.

---

## 6. Plugin Auto-Install

### 6.1 Mechanism

The Claude Code CLI exposes `claude plugin` subcommands. The installer uses:

- `claude plugin marketplace add <github-repo>` — register a marketplace.
- `claude plugin marketplace list` — check whether a marketplace is already added.
- `claude plugin install <plugin>@<marketplace>` — install a plugin.
- `claude plugin list` — check whether a plugin is already installed.

### 6.2 Target marketplaces and plugins

| Marketplace | GitHub repo | Plugins to install |
|-------------|-------------|---------------------|
| `claude-plugins-official` | `anthropics/claude-plugins-official` | `superpowers`, `code-review` |
| `karpathy-skills`         | `forrestchang/andrej-karpathy-skills` | `andrej-karpathy-skills` |

### 6.3 `graphify` handling

`graphify` is not installed via `claude plugin`. The installer only verifies presence by checking `~/.claude/skills/graphify/`:

- If present: log `graphify skill detected`.
- If absent: log a warning with a manual-install hint. Installation is not attempted.

### 6.4 Pseudocode

```bash
ensure_marketplace() {            # name, repo
  claude plugin marketplace list 2>/dev/null | grep -q "^$1\b" \
    || claude plugin marketplace add "$2"
}

ensure_plugin() {                 # plugin, marketplace
  claude plugin list 2>/dev/null | grep -q "$1@$2" \
    || claude plugin install "$1@$2"
}
```

Both helpers tolerate failures (the calling phase records the failure into the summary but does not abort).

---

## 7. Common-Core Hook Set (`common/.claude/settings.json`)

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

These two hooks are entirely framework-agnostic — they remind Claude about an existing knowledge graph and inject the six-phase workflow context when feature-request keywords appear.

### Language overlay hooks (shape, not full content)

Each `langs/<x>/.claude/settings.json` contains:

- **`PreToolUse` with matcher `Bash` and `if: "Bash(git commit*)"`** — runs the language test runner; on non-zero exit, returns `permissionDecision: "deny"` with the captured output.
- **A second `PreToolUse` block, same matcher, `if: "Bash(git commit*)"`** — runs the language linter; same deny pattern.
- **`PostToolUse` with matcher `Write|Edit`** — checks the touched file path against the language extension (`.rb`, `.py`, `.go`) and runs the formatter/linter on that single file.

Exact commands per language:

| Language | Test command | Lint command | PostToolUse |
|----------|--------------|--------------|-------------|
| Rails    | `bin/rails test` | `bin/rubocop --format quiet` | `.rb` → `bin/rubocop "$f"` |
| Python   | `pytest -q` | `ruff check .` | `.py` → `ruff format "$f" && ruff check "$f"` |
| Go       | `go test ./...` | `golangci-lint run` | `.go` → `gofmt -w "$f" && go vet ./...` |

---

## 8. Migration from Current State

Current `~/projects/00.base-files/` contains:

```text
CLAUDE.md
docs/standards/{RULES,WORKFLOW,QUALITY,STACK,TOOLS}.md
.claude/settings.json
.claude/hooks/pipeline-reminder.txt
```

All of which are Rails-flavored. Migration to the new layout:

1. **Move existing Rails files into `langs/rails/`:**
   - `docs/standards/STACK.md` → `langs/rails/docs/standards/STACK.md` (no edits)
   - `docs/standards/TOOLS.md` → `langs/rails/docs/standards/TOOLS.md` (no edits)
   - `.claude/settings.json` Rails-specific hooks → `langs/rails/.claude/settings.json`

2. **Create `common/` versions:**
   - `common/CLAUDE.md` — copy current `CLAUDE.md`, strip Rails-specific table rows and re-link `STACK.md`/`TOOLS.md` as overlay-installed.
   - `common/docs/standards/RULES.md` — copy current `RULES.md` (already neutral).
   - `common/docs/standards/WORKFLOW.md` — copy current `WORKFLOW.md` (already neutral).
   - `common/docs/standards/QUALITY.md` — rewrite, removing all tool names and Rails-specific sections; keep principles + accessibility + evidence-driven self-diagnosis.
   - `common/docs/standards/REVIEW.md` — extract "Code Review Checklist" from current `QUALITY.md`; remove `bin/*` references, replace with neutral pointers to `TOOLS.md`.
   - `common/.claude/settings.json` — keep only the `Glob|Grep` graphify hook and the `UserPromptSubmit` pipeline-reminder hook.
   - `common/.claude/hooks/pipeline-reminder.txt` — copy current file (already neutral).

3. **Create `langs/python/` and `langs/go/` from scratch.**
   - `STACK.md` and `TOOLS.md` written per-language at the same depth as the current Rails `STACK.md` (~200-300 lines each).
   - `settings.json` hooks per the table in §7.

4. **Add `install.sh`, `lib/*.sh`, `README.md`, `VERSION`.**

5. **Validation:**
   - Dry-run the installer against a temporary directory containing only a `Gemfile` → expect Rails overlay to apply.
   - Dry-run against a directory containing only `pyproject.toml` → expect Python overlay.
   - Dry-run against a directory containing only `go.mod` → expect Go overlay.
   - Dry-run against an empty directory → expect interactive prompt.
   - Re-run on a populated target → expect timestamped backups and no destructive overwrites.

---

## 9. Open Questions

These are not blockers for the design but should be answered during implementation:

1. **Where do `langs/python/STACK.md` and `langs/go/STACK.md` content come from?** No equivalent of the current Rails `STACK.md` exists yet. The author needs to draft them. v1 will ship with skeletal versions; the user can flesh them out as real projects are bootstrapped.
2. **Should the installer write a small marker file (e.g. `.base-files-version`) into the target?** Would help future `--upgrade` flows distinguish a base-files-managed target from a hand-rolled one. Out of scope for v1 but worth a placeholder line in `VERSION` to support later.
3. **`graphify` installation hint.** What is the actual install command? The skill currently lives at `~/.claude/skills/graphify/` but the installer doesn't know how it got there. The user should provide the canonical install command for the README.

---

## 10. Implementation Order (preview for writing-plans)

This section is a forward reference for the next skill (writing-plans), not part of the design decision itself:

1. Create `common/` files (copy + edit existing) — no installer needed; pure file moves.
2. Create `langs/rails/` files — pure file moves from current `docs/standards/` and `.claude/settings.json`.
3. Stub `langs/python/` and `langs/go/` with minimum viable `STACK.md`/`TOOLS.md`/`settings.json`.
4. Implement `lib/log.sh` (utilities first).
5. Implement `lib/detect-language.sh` + `lib/check-deps.sh` (read-only).
6. Implement `lib/copy-files.sh` + `lib/merge-settings.sh` (file mutations).
7. Implement `lib/install-skills.sh` (`claude plugin` orchestration).
8. Wire `install.sh` entry point.
9. Write `README.md`.
10. Smoke-test against the four scenarios listed in §8 step 5 (Validation).
