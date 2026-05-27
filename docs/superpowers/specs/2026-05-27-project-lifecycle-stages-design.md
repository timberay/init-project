# Project Lifecycle Stages

**Date:** 2026-05-27
**Status:** Draft — pending user review
**Scope:** This `init-project` template AND every project bootstrapped from it.

## Problem

`WORKFLOW.md` defines a six-phase pipeline (Phase 1 Product → Phase 6 Ship) that is **per-feature** — the lifecycle of *one* feature from idea to merged PR. There is no standard for the **per-project** lifecycle — "is this project still being set up, internally usable, in production, in maintenance, or done?"

Consequence: `PROJECT_STATE.md` already tracks an *Active Work* slot (the current feature in flight), but a fresh contributor or AI session cannot tell at a glance which lifecycle posture the project is in. A bug fix in a Pilot project should be treated differently than the same bug fix in a Launch project (deployment risk, change control, user-impact assumptions), and today nothing in the orchestrator surfaces that distinction.

## Goals

- A single, project-wide field that answers "which lifecycle stage is this project in *right now*?"
- A common stage vocabulary that applies to all projects bootstrapped from this template (services, libraries, CLIs, PoCs).
- Stage transitions captured durably (ADR) for the transitions that matter; lightweight (`/state-sync` only) for the trivial ones.
- Orthogonal to the existing six-phase feature pipeline — never blocks or overlaps it.

## Non-Goals

- **Not a gate.** No pre-commit or CI rule enforces stages. Soft convention only. (Promoting to enforced gates is a separate future decision, like ADR-0001 was.)
- **Not a schedule or WBS in the PM sense.** No time estimates, no resource planning, no dependency graph between stages — visibility only.
- **Not per-stage quality bars.** SLA, test coverage, security thresholds live in `QUALITY.md`, orthogonal to stage.
- **Not multi-team governance.** Single-project, single-owner assumption (consistent with `PROJECT_STATE.md` Out of Scope).

## Solution Overview

All paths below are **template source paths** in this `init-project` repo. After `install.sh` bootstrap, the `common/` prefix is stripped — a deployed downstream project sees `CLAUDE.md`, `PROJECT_STATE.md`, `docs/standards/LIFECYCLE.md`, `docs/decisions/...` at its own root.

```
init-project/                                       # template source (this repo)
├── common/
│   ├── CLAUDE.md                                   # EDIT — Standards Reference + Task→Required Reading rows extended
│   ├── PROJECT_STATE.md                            # EDIT — header gains "Lifecycle Stage: Setup (since YYYY-MM-DD)"
│   └── docs/
│       └── standards/
│           └── LIFECYCLE.md                        # NEW — stage definitions, transition rules
├── install.sh                                      # EDIT — substitutes YYYY-MM-DD with today's date on bootstrap
├── PROJECT_STATE.md                                # EDIT (this repo's own) — Lifecycle Stage: Pilot (since 2026-05-23)
└── docs/
    └── decisions/
        └── ADR-0003-adopt-lifecycle-stages.md      # NEW — captures this decision
```

Five stages, monotonically forward, with forward-skips allowed:

`Setup → Pilot → Launch → Maintenance → Archive`

| Stage | Meaning | Entry signal | Exit signal |
|---|---|---|---|
| **Setup** | Scaffolding, environment, toolchain. No domain logic yet. | `git init` / `install.sh` completion (auto) | First domain-code commit lands |
| **Pilot** | Core scenario runs end-to-end. Internal/early users only. Fragile. | First commit running the main use case — user declaration | Intended external users start to depend on it |
| **Launch** | External / production users. SLA and operational ownership exist. Changes are deliberate. | First deploy exposed externally — user declaration | New-feature work largely stops, only stabilization and bug fixes remain |
| **Maintenance** | No major new work. Upkeep and incremental improvement. | After Launch, when feature-work cadence drops — user declaration | Project sunset decision |
| **Archive** | No longer actively developed or operated. Code retained, no changes. | Sunset decision ADR | (terminal) |

**Three core rules:**

1. **Monotonic forward, skips allowed.** A library may go `Setup → Pilot → Maintenance` (no Launch). A PoC may go `Setup → Pilot → Archive`. Backward transitions are illegal — a Launch→Pilot regression requires an explicit "regression ADR" (see §6 Edge Cases).
2. **Transitions are confirmed by user declaration.** Entry signals are guidance; the transition is real only after `/state-sync` updates `PROJECT_STATE.md` (and, where required, a `/decide` ADR lands).
3. **Stage is orthogonal to Feature Phase.** A project at Stage = Pilot can still run any feature through Phases 1–6. Stage does not modify the pipeline; it modifies the *posture* of work done within it (e.g., `/document-release` may be lighter in Pilot than in Launch).

## Detailed Design

### 1. Stage definitions and transition criteria

(See the table in *Solution Overview* for the canonical definitions.) `LIFECYCLE.md` is the single source of truth for stage semantics; `PROJECT_STATE.md` carries only the current value.

### 2. `PROJECT_STATE.md` integration

The header gains one line, placed immediately under the title:

```markdown
# PROJECT_STATE

> Lifecycle Stage: Pilot (since 2026-05-23)
> Last Updated: 2026-05-27T... by <name> (session: <slug>)

## Current Phase
...
```

- **Value:** exactly one of `Setup`, `Pilot`, `Launch`, `Maintenance`, `Archive`.
- **`since` date:** the date the project *entered* the current stage. Preserved across edits; updated only on real transitions.
- **Cardinality:** exactly one stage per project. Repos hosting multiple independent projects are out of scope (see §6).
- **Seed:** `install.sh` initializes new projects to `Setup (since <today>)`.

### 3. Transition obligations

| Transition | Required artifacts | Recommended artifacts |
|---|---|---|
| **Setup → Pilot** | `/state-sync` (header update) | Short ADR describing the first domain feature (optional) |
| **Pilot → Launch** | `/decide` ADR (**required**) + `/state-sync` + README updated for external audience | Deployment/ops procedure, SLA definition |
| **Launch → Maintenance** | `/decide` ADR (**required**, recording *why* new-feature work is winding down) + `/state-sync` | `Out of Scope` section of `PROJECT_STATE.md` refreshed |
| **Maintenance → Archive** | `/decide` ADR (**required**, archive decision) + `/state-sync` + README marked "archived" | Sunset retrospective notes |
| **Forward skip** (e.g., Pilot → Maintenance, Pilot → Archive) | Only the **destination** transition's required artifacts | — |

Rationale:

- Setup→Pilot is frequent and low-stakes, so it does not warrant an ADR.
- The remaining transitions are real product decisions (audience, operational posture, sunset) and deserve a durable record.
- A skipped stage means the stage *never applied* to the project (a library is never in Launch; a PoC is never in Maintenance). There is no decision to record about leaving a posture the project never had — only the destination transition's ADR is required.
- No automated enforcement. The orchestrator pattern is "warn, do not reject" (consistent with ADR-0000 and ADR-0001).

### 4. Stage posture for AI agents

The stage label is load-bearing only if AI sessions adjust their behavior to match. `LIFECYCLE.md` defines the following posture per stage. AI agents that read `PROJECT_STATE.md` MUST adopt the posture matching the current stage; if a user request conflicts with that posture, the agent surfaces the conflict and suggests either deferring the request or transitioning the stage first.

| Stage | Default posture | What to lean into | What to push back on |
|---|---|---|---|
| **Setup** | Foundation-first. | Build env, linter, CI, scaffolding, repo layout, ADR baseline. | Domain features before tooling exists ("write the linter config first"). |
| **Pilot** | Speed over rigor. | Rapid prototyping, exercising the core scenario end-to-end, accepting interface churn. | Demands for strict test coverage, exhaustive edge-case handling, formal migration plans. Suggest revisiting at Launch. |
| **Launch** | Stability and backwards compatibility. | Tests, migration plans, changelogs, deliberate change control, user-impact review on every breaking change. | "Just rewrite it" / "let's break the API" without a documented migration and ADR. |
| **Maintenance** | Bug fixes and refactors only. | Defect repair, security patches, dependency upkeep, incremental polish. | New features. If the user requests one, surface "this looks like new-feature work — consider transitioning out of Maintenance first" and pause for confirmation. |
| **Archive** | Read-only. | Questions, archaeology, doc updates that clarify the archived state. | All code changes. If a change is genuinely needed, require a `Reactivation ADR` returning the project to Pilot before any edit. |

These postures are guidance, not hard rules — the user can always override with explicit instruction. The point is that the *default* matches the project's operational reality.

### 5. Document and tooling changes

Five files change in lockstep when this design is accepted:

1. **NEW:** `common/docs/standards/LIFECYCLE.md` — full standard (this design's content, distilled to ≤100 lines).
2. **EDIT:** `common/CLAUDE.md` — Standards Reference table gains a `LIFECYCLE.md` row; Task→Required Reading table gains a `Lifecycle stage transition / archive decision → LIFECYCLE` row.
3. **EDIT:** `common/PROJECT_STATE.md` (template) — header gains the `Lifecycle Stage:` line, seeded with `Setup (since YYYY-MM-DD)`.
4. **EDIT:** `install.sh` — template substitution replaces `YYYY-MM-DD` with today's date during bootstrap.
5. **EDIT:** `PROJECT_STATE.md` (this repo) — `Lifecycle Stage: Pilot (since 2026-05-23)` added. The repo itself is in Pilot — the orchestrator standard is usable but actively expanding.

`/state-sync` is *not* required to change for adoption. The slash command already accepts free-form edits to `PROJECT_STATE.md` and can update the header line as part of a normal sync. Two enhancements are left as future work, not in scope for adoption: (a) an optional `--stage <Stage>` argument that triggers the obligation-checklist from §3, and (b) a soft-validation warning when the stage value does not match one of the five canonical labels (`Setup` / `Pilot` / `Launch` / `Maintenance` / `Archive`) — to catch typos like `Beta`, `Active`, `Testing` without rejecting the edit.

### 6. Edge cases

| Case | Stage path | Note |
|---|---|---|
| Library (npm / gem / pypi distributed) | `Setup → Pilot → Maintenance` (skip Launch) | "Launch = external operational burden" does not apply to a published library; stabilization is sufficient. |
| PoC / learning project | `Setup → Pilot → Archive` | Skipping Launch and Maintenance is normal. Required artifacts apply only on entry to Archive. |
| Reactivated project (Archive → active again) | New ADR declaring re-entry to Pilot | The only legitimate "backwards" move. `since` resets to the re-entry date; prior entry date preserved in the ADR body. |
| Launch → Pilot regression (severe defect found) | Separate "regression to Pilot" ADR | Not a `/supersede` — a new ADR that updates the stage slot. |
| Monorepo (N independent projects in one repo) | Out of scope for this standard | Repo split recommended. If unavoidable, per-subproject `PROJECT_STATE.md`. The template assumes 1 repo = 1 project. |
| Project doing only bug fixes / refactors | No stage change | Stage tracks *operational mode*, not activity volume. |

### 7. Migration

**This repo (`init-project`):** the five lockstep changes above land in one PR alongside `ADR-0003`. An e2e seed assertion is added: bootstrapped projects must have a `Lifecycle Stage:` line in their `PROJECT_STATE.md`.

**Existing downstream projects (already bootstrapped before this PR):** no automated migration. Each project manually adds the header line, choosing its current stage by self-assessment. A formal ADR for the initial declaration is optional — this is *initial labeling*, not a *transition*.

## Adoption as ADR-0003

The set of changes above (new file, edited template, edited CLAUDE.md, edited install.sh, repo's own stage declaration) constitutes one decision and ships as one ADR:

- **Title:** Adopt project lifecycle stages (Setup→Pilot→Launch→Maintenance→Archive)
- **Status:** Accepted (on user approval)
- **Date:** 2026-05-27
- **Consequences:** Listed in §5. No new dependencies; no enforcement layer; one new standard file; one header line in every project; AI sessions will adjust posture per §4.

## Open Questions

None at design time. The deliberate deferrals are recorded as Non-Goals (no hard enforcement) and as a future enhancement (`/state-sync --stage` flag).
