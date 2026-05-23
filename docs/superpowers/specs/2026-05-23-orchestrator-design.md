# Orchestrator: PROJECT_STATE + ADR + Hooks

**Date:** 2026-05-23
**Status:** Draft — pending user review
**Scope:** This `init-project` template AND every project bootstrapped from it.

## Problem

AI-driven development in projects bootstrapped from this template exhibits three recurring failures:

1. **Decision reversal** — AI flips previously settled decisions because nothing tells it "this is locked."
2. **History blindness** — AI answers without reading prior decisions or design docs.
3. **State misjudgment** — AI reads the wrong artifact (or a stale one) and infers a current state that is no longer true.

Root cause: there is no single, authoritative "Orchestrator" surface that says *where we are*, *what is decided*, and *which document is current truth*. The existing six-phase pipeline (`WORKFLOW.md`) addresses *process*, but Phase 1·2 outputs live under `~/.gstack/projects/<slug>/designs/` (per-developer, not committed), so a fresh AI session cannot see them at all.

## Goals

- A single place an AI session reads first to know *where the project is*.
- An append-only decision record so reversals require an explicit supersede, not silent drift.
- Soft enforcement that makes the right path the easy path — no hard blocking that disrupts normal work.
- Zero dependency on `gstack` so it works in every bootstrapped project.

## Non-Goals

- Replacing the six-phase pipeline. This is a layer **above** it.
- Re-committing Phase 1·2 raw outputs in-repo. We extract only the **decisions** into ADRs.
- Multi-team governance / approval workflows.
- Hard pre-commit blocks. We warn, we do not reject.

## Solution Overview

```
<project>/
├── PROJECT_STATE.md                    # "Where we are" — single page, <100 lines
├── docs/
│   └── decisions/                      # ADR directory (append-only)
│       ├── README.md                   #   Index: number · title · status (1 line each)
│       ├── ADR-0000-bootstrap.md       #   This mechanism itself, as ADR-0000
│       └── ADR-NNNN-*.md
└── .claude/
    ├── settings.json                   # Registers the hooks below
    ├── hooks/
    │   ├── sessionstart-inject-state.sh
    │   ├── userpromptsubmit-remind.sh
    │   └── pretooluse-stale-check.sh
    └── commands/                       # Slash commands (semi-automatic authoring)
        ├── decide.md
        ├── state-sync.md
        └── supersede.md
```

Three components do three different jobs:

| Component | Question it answers | Authority |
|---|---|---|
| `PROJECT_STATE.md` | "Where are we *right now*?" | Mutable, single page, always current |
| `docs/decisions/ADR-*.md` | "What did we decide, and why?" | Immutable; reversal requires a new ADR |
| `.claude/hooks/*.sh` | "How do we make AI actually read these?" | Soft injection + stale-check at risk points |

Maps to the three problems:

| Problem | Solved by |
|---|---|
| Decision reversal | ADRs are append-only. `Accepted` cannot be edited; only superseded by a new ADR that explicitly references the old one. UserPromptSubmit hook catches "이전에/다시/왜 X" keywords and forces an index read. |
| History blindness | SessionStart hook injects `PROJECT_STATE.md` + ADR index into the first response context. AI cannot claim ignorance. |
| State misjudgment | `PROJECT_STATE.md` is the *only* authoritative state surface. PreToolUse hook warns when it is stale (>7 days) before edits/writes. |

## Components

### 1. PROJECT_STATE.md

A single page, always under 100 lines, with six fixed sections:

```markdown
# PROJECT_STATE

> Last Updated: 2026-05-23T14:00:00+09:00 by tonny (session: brainstorm-orchestrator)

## Current Phase
- Phase: 3 — Technical Design
- Active Spec: docs/superpowers/specs/2026-05-23-orchestrator-design.md
- Active Plan: (not yet)

## Locked Decisions
See `docs/decisions/README.md` for the full index. Most recent:
- ADR-0000 — Adopt PROJECT_STATE + ADR + Hooks orchestrator (Accepted, 2026-05-23)

## Active Work
- [in-progress] Orchestrator design — brainstorm phase, spec drafted
- [blocked] ...

## Open Questions
- (none)

## Out of Scope
- Multi-team approval workflows
- Pre-commit hard blocks

## Last Updated
2026-05-23T14:00:00+09:00 (see header)
```

Rules:
- **Hard cap: ~100 lines.** If you need more, you are using the wrong file — that belongs in an ADR or spec.
- **Locked Decisions section never holds reasoning** — only pointers to ADRs.
- **Out of Scope** exists to silence repeated suggestions ("AI keeps proposing X — we said no").

### 2. ADR Format

Numbered, immutable, single-purpose. Following Michael Nygard's minimal ADR:

```markdown
# ADR-0007: Use SQLite for development, Postgres in production

- **Status:** Accepted
- **Date:** 2026-05-23
- **Supersedes:** (none)
- **Superseded by:** (none)

## Context
Why does this decision need to be made? What forces are at play?

## Decision
What did we decide?

## Consequences
What follows from this — positive, negative, neutral.
```

Status values:
- `Proposed` — under discussion, AI may challenge
- `Accepted` — locked; only a new ADR with `Supersedes: ADR-NNNN` can reverse
- `Superseded by ADR-NNNN` — historical, do not act on
- `Rejected` — was proposed, decided against (kept for the record)

Numbering: monotonic, starting at 0000. Never reused. Never renumbered.

**Immutability is by convention, not by hook.** In this Medium-strength setup, nothing in `git` or the hooks prevents editing the body of an `Accepted` ADR. The discipline is documented in CLAUDE.md and surfaced via the slash commands (`/supersede` will only edit the status header, never the body). Upgrading to a pre-commit hard block is a future option, captured as a separate ADR if and when adopted.

The index (`docs/decisions/README.md`) is one line per ADR:

```markdown
# Architecture Decision Records

| # | Title | Status | Date |
|---|---|---|---|
| 0000 | Adopt STATE + ADR + Hooks orchestrator | Accepted | 2026-05-23 |
| 0001 | ... | Accepted | ... |
```

### 3. Slash Commands (semi-automatic authoring)

User triggers, AI fills the draft, user approves before save. Three commands ship in `common/.claude/commands/`:

#### `/decide`
- AI scans the current conversation, identifies the decision, drafts an ADR with all fields.
- Shows the draft to the user.
- On approval: writes to `docs/decisions/ADR-NNNN-<slug>.md` (next available number), updates the index, optionally appends one line to PROJECT_STATE.md "Locked Decisions."

#### `/state-sync`
- AI reads the current PROJECT_STATE.md, then surveys recent activity (git log, open files, the conversation).
- Produces a diff of what should change in PROJECT_STATE.md.
- User approves the diff, then it is applied. "Last Updated" is bumped automatically.

#### `/supersede ADR-NNNN`
- AI reads ADR-NNNN, asks for the new decision.
- Creates a new ADR with `Supersedes: ADR-NNNN` populated.
- Edits ADR-NNNN: sets `Status: Superseded by ADR-MMMM`. (This is the **only** post-acceptance edit permitted on an ADR — the status header.)

### 4. Hooks (Medium enforcement)

Three shell scripts in `common/.claude/hooks/`, wired through `common/.claude/settings.json`.

#### `sessionstart-inject-state.sh`
Triggered: `SessionStart`.
Output: prints PROJECT_STATE.md (if present) followed by docs/decisions/README.md (if present) as additional context.
If neither exists: prints a one-line nudge ("This project has no PROJECT_STATE.md yet — run /state-sync to bootstrap").

#### `userpromptsubmit-remind.sh`
Triggered: `UserPromptSubmit`.
Detects Korean + English keywords suggesting prior context: `이전에|예전|전에 결정|다시|왜 .* 했|previously|earlier|why did we|revisit`.
On match: appends a reminder to the prompt context — "→ Check `docs/decisions/README.md` index before answering. Decisions live in ADRs, not git log."

#### `pretooluse-stale-check.sh`
Triggered: `PreToolUse` on `Edit`, `Write`, `NotebookEdit`.
Checks:
- `PROJECT_STATE.md` exists. If not → stderr warn, do not block.
- `PROJECT_STATE.md` mtime within last 7 days. If older → stderr warn ("PROJECT_STATE.md is N days stale. Run /state-sync."), do not block.
Default threshold 7 days, configurable via `STATE_STALE_DAYS` env.

No hook blocks. All three are soft: SessionStart and UserPromptSubmit add context; PreToolUse prints to stderr so the user sees it in the transcript.

## Workflow Integration

The existing six-phase pipeline (`WORKFLOW.md`) is unchanged in structure. Hooks into it:

| Phase | Orchestrator hook |
|---|---|
| 1 (Product) | On completion: `/decide` to capture WHAT/WHY as an ADR (the design doc itself stays under `~/.gstack/`, but the decision is preserved in-repo). |
| 2 (Architecture) | On completion: `/decide` for each major architectural choice (data flow, module boundaries). |
| 3 (Technical Design) | Spec file path is recorded in `PROJECT_STATE.md → Active Spec`. `/state-sync` after writing the spec. |
| 4 (Task Breakdown) | Plan path recorded in `PROJECT_STATE.md → Active Plan`. `/state-sync` after writing the plan. |
| 5 (Execute) | `/state-sync` at logical checkpoints (not per task — too noisy). |
| 6 (Ship) | After merge: `/state-sync` clears "Active Work" entry; `/decide` if the shipped work locked any new technical choices. |

`WORKFLOW.md` gets a new top-level section "**Orchestrator (STATE + ADR)**" with a one-paragraph summary and a pointer to ADR-0000.

`CLAUDE.md` (common) gets a new section near the top — **after** "Non-Negotiable Rules", **before** "Standards Reference" — stating that PROJECT_STATE.md and `docs/decisions/README.md` are required reading at session start.

## Template Integration (`common/`)

Files added to the template, copied into every bootstrapped project by `install.sh`:

```
common/
├── PROJECT_STATE.md                              # blank stub with the 6 sections, "Last Updated: never"
├── docs/
│   └── decisions/
│       ├── README.md                             # index header + ADR-0000 row
│       └── ADR-0000-orchestrator-bootstrap.md    # this mechanism's own first ADR
├── .claude/
│   ├── settings.json                             # adds three hook entries
│   ├── hooks/
│   │   ├── sessionstart-inject-state.sh
│   │   ├── userpromptsubmit-remind.sh
│   │   └── pretooluse-stale-check.sh
│   └── commands/
│       ├── decide.md
│       ├── state-sync.md
│       └── supersede.md
└── CLAUDE.md                                     # add "Orchestrator" section
```

`common/docs/standards/WORKFLOW.md` gets the per-phase hook table above.

`install.sh` already copies `common/` recursively; the merge-settings step (lib/merge-settings.sh) handles `.claude/settings.json` deep-merge. New hooks and commands fall out for free. No installer changes needed beyond verifying hook scripts are executable.

`tests/`:
- `tests/smoke_*.sh` — assert PROJECT_STATE.md, docs/decisions/README.md, ADR-0000, and the three hook scripts land in the test project.
- `tests/test_orchestrator_hooks.sh` (new) — unit-test the three hook scripts: keyword detection, stale threshold, missing-file behavior.

## Migration (for projects already bootstrapped)

A bootstrapped project that predates this change can adopt it by re-running `install.sh --force` (existing files are backed up). The user manually writes their first real PROJECT_STATE.md afterward — the template stub is just a skeleton.

For this `init-project` repo itself: we adopt the mechanism in the same PR that introduces it. ADR-0000 IS the meta-decision to introduce it.

## Open Questions

None remaining for this draft. Detail decisions (exact keyword list, exact stale threshold, exact slash command prompt templates) are implementation choices, deferred to the plan.

## Acceptance Criteria

1. A fresh AI session opens a bootstrapped project and, before its first response, has read PROJECT_STATE.md and the ADR index (verified by SessionStart hook output appearing in transcript).
2. Asking "왜 X 했더라" triggers the UserPromptSubmit reminder.
3. Editing code while PROJECT_STATE.md is >7 days stale produces a stderr warning visible to the user.
4. `/decide`, `/state-sync`, `/supersede` exist as slash commands and produce drafts that the user can approve before save.
5. ADR-0000 exists in this repo, documenting this decision.
6. All smoke tests pass; the new hook unit tests pass.
