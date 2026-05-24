# base-files

Multi-language base template for new projects. One command installs common
guidance, language-specific tooling, and Claude Code plugins into a fresh
project directory.

Supported overlays: **Rails 8 · Python (FastAPI/Django) · Go**.

> For the full reference (every flag, every phase, walkthroughs per language,
> troubleshooting, and how to add a new language overlay), see
> [`docs/USAGE.md`](docs/USAGE.md).

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
├── .editorconfig                        (common)
├── .gitignore                           (language overlay)
├── .pre-commit-config.yaml              (language overlay — commit-time fast checks, ADR-0001)
├── .github/
│   └── workflows/
│       └── ci.yml                       (language overlay — CI: pre-commit + tests on PR / push to main)
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

`graphify` and `gstack` are **verified** (not installed) by the installer —
both live outside the claude plugin marketplaces. `gstack` is referenced by
`WORKFLOW.md` phases 1, 2, and 6; install it manually if you want the full
pipeline. Without it, those phases need manual substitutes.

### Bundled project skills (installed into the project itself)

| Skill      | Where it lands                              | Purpose                                                              |
|------------|---------------------------------------------|----------------------------------------------------------------------|
| `push2gh`  | `<project>/.claude/skills/push2gh/SKILL.md` | Commit → push → PR → optional automerge → cleanup. `gstack`-free phase 6 substitute. |

Bundled skills are snapshots committed into this template. They are upgraded
manually — see `docs/USAGE.md` for the resync procedure.

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
