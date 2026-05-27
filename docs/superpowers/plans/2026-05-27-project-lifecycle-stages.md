# Project Lifecycle Stages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-project lifecycle stage standard (Setup → Pilot → Launch → Maintenance → Archive) to the orchestrator, surfaced as one line in `PROJECT_STATE.md` and defined in a new `LIFECYCLE.md` standard.

**Architecture:** Five lockstep changes plus an ADR. The template (`common/`) gains the new standard and a seeded header line; `install.sh` substitutes today's date during bootstrap; this repo's own `PROJECT_STATE.md` records its current stage; a smoke-test grep proves the seed substitution works.

**Tech Stack:** Bash (install.sh + tests), Markdown (standards + ADRs), no new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-27-project-lifecycle-stages-design.md`

---

## File structure

| Path | Action | Purpose |
|---|---|---|
| `tests/smoke_empty.sh` | EDIT | TDD assertion that bootstrap seeds the Lifecycle Stage line with today's date |
| `common/PROJECT_STATE.md` | EDIT | Template header gains `> Lifecycle Stage: Setup (since YYYY-MM-DD)` |
| `install.sh` | EDIT | New post-copy step substitutes `YYYY-MM-DD` with `$(date +%Y-%m-%d)` |
| `common/docs/standards/LIFECYCLE.md` | NEW | The standard itself (≤100 lines) |
| `common/CLAUDE.md` | EDIT | Standards Reference row + Task→Required Reading row |
| `PROJECT_STATE.md` (this repo) | EDIT | Declare this repo's stage: `Pilot (since 2026-05-23)` + ADR-0003 pointer |
| `docs/decisions/ADR-0003-adopt-lifecycle-stages.md` | NEW | The decision, Accepted |
| `docs/decisions/README.md` | EDIT | Index row for ADR-0003 |

---

### Task 1: Add failing smoke assertion for Lifecycle Stage seed

**Files:**
- Modify: `tests/smoke_empty.sh:53` (after the existing `[[ -f "$TMP/PROJECT_STATE.md" ]]` check)

- [ ] **Step 1: Write the failing test**

In `tests/smoke_empty.sh`, find the block that begins with `# Orchestrator: STATE + ADR + hooks + commands must land` (around line 53). Right after the line `[[ -f "$TMP/PROJECT_STATE.md" ]] || fail "PROJECT_STATE.md not installed"`, insert:

```bash
TODAY="$(date +%Y-%m-%d)"
grep -q "^> Lifecycle Stage: Setup (since ${TODAY})$" "$TMP/PROJECT_STATE.md" \
  || fail "PROJECT_STATE.md missing seeded 'Lifecycle Stage: Setup (since ${TODAY})' line"
ok "PROJECT_STATE.md seeded with Lifecycle Stage line dated today"
```

- [ ] **Step 2: Run smoke to verify it fails**

Run: `RUN_SMOKE=1 tests/run_all.sh 2>&1 | tail -40`
Expected: failed tests include `smoke_empty.sh`, with the message `FAIL: PROJECT_STATE.md missing seeded 'Lifecycle Stage: Setup (since <today>)' line`.

- [ ] **Step 3: Commit (red)**

```bash
git add tests/smoke_empty.sh
git commit -m "test(smoke): assert install.sh seeds Lifecycle Stage line (failing)"
```

---

### Task 2: Add Lifecycle Stage line to the template `PROJECT_STATE.md`

**Files:**
- Modify: `common/PROJECT_STATE.md:1-4` (header)

- [ ] **Step 1: Replace the template header**

Replace the first 4 lines of `common/PROJECT_STATE.md`:

Old:
```markdown
# PROJECT_STATE

> Last Updated: never (run `/state-sync` to populate)

```

New:
```markdown
# PROJECT_STATE

> Lifecycle Stage: Setup (since YYYY-MM-DD)
> Last Updated: never (run `/state-sync` to populate)

```

- [ ] **Step 2: Run smoke — assertion still fails (placeholder not yet substituted)**

Run: `RUN_SMOKE=1 tests/run_all.sh 2>&1 | tail -40`
Expected: `smoke_empty.sh` still fails with the same message — the template has `YYYY-MM-DD` literal, not today's date. This proves the substitution in Task 3 is what flips it green.

- [ ] **Step 3: Commit**

```bash
git add common/PROJECT_STATE.md
git commit -m "feat(state): add Lifecycle Stage header line to PROJECT_STATE.md template"
```

---

### Task 3: Substitute today's date in `install.sh` post-copy

**Files:**
- Modify: `install.sh` (add a new step after `copy_files` returns, before `merge_settings`)

- [ ] **Step 1: Locate the insertion point**

Run: `grep -n 'copy_files\|merge_settings\|log_section' install.sh`
Expected output (approximate):
```
74:log_section "3/5  Copying common + $DETECTED_LANG files"
75:copy_files \
80:  "$DRY_RUN" || exit $?
...
```
Note the line right after `copy_files` succeeds and before the next `log_section`.

- [ ] **Step 2: Insert the substitution block**

Immediately after the `copy_files \ ... "$DRY_RUN" || exit $?` block (around line 80), insert:

```bash

if [[ "$DRY_RUN" -ne 1 && -f "$TARGET/PROJECT_STATE.md" ]]; then
  TODAY="$(date +%Y-%m-%d)"
  # Seed only the literal placeholder, leave any real date alone.
  if grep -q "Lifecycle Stage: Setup (since YYYY-MM-DD)" "$TARGET/PROJECT_STATE.md"; then
    # Cross-platform sed-in-place: write to a temp file, then move.
    sed "s/Lifecycle Stage: Setup (since YYYY-MM-DD)/Lifecycle Stage: Setup (since ${TODAY})/" \
      "$TARGET/PROJECT_STATE.md" > "$TARGET/PROJECT_STATE.md.tmp" \
      && mv "$TARGET/PROJECT_STATE.md.tmp" "$TARGET/PROJECT_STATE.md"
    log_ok "seeded Lifecycle Stage date: ${TODAY}"
  fi
fi
```

Rationale:
- Guarded with `DRY_RUN -ne 1` so `--dry-run` stays a pure preview.
- Guarded with the placeholder grep so re-running `install.sh` on an existing project with a real stage value does not overwrite it.
- Uses the temp-file-then-mv pattern instead of `sed -i` because BSD sed (macOS) and GNU sed disagree on the in-place flag syntax.

- [ ] **Step 3: Run smoke — assertion now passes**

Run: `RUN_SMOKE=1 tests/run_all.sh 2>&1 | tail -40`
Expected: `smoke_empty.sh` passes; summary shows `failed: 0`.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(install): seed Lifecycle Stage date on bootstrap"
```

---

### Task 4: Create `common/docs/standards/LIFECYCLE.md`

**Files:**
- Create: `common/docs/standards/LIFECYCLE.md`

- [ ] **Step 1: Write the file**

Create `common/docs/standards/LIFECYCLE.md` with this exact content:

````markdown
# Project Lifecycle Stages

> One project, one stage. The Lifecycle Stage answers "where is the project right now?" — orthogonal to the per-feature six-phase pipeline in `WORKFLOW.md`. `PROJECT_STATE.md` carries the current value; this file defines what each value means.

## Stages

| Stage | Meaning | Entry signal | Exit signal |
|---|---|---|---|
| **Setup** | Scaffolding, environment, toolchain. No domain logic yet. | `git init` / `install.sh` completion (auto) | First domain-code commit lands |
| **Pilot** | Core scenario runs end-to-end. Internal / early users only. Fragile. | First commit running the main use case — user declaration | Intended external users start to depend on it |
| **Launch** | External / production users. SLA and operational ownership exist. Changes are deliberate. | First deploy exposed externally — user declaration | New-feature work largely stops |
| **Maintenance** | No major new work. Upkeep and incremental improvement. | After Launch, when feature-work cadence drops — user declaration | Project sunset decision |
| **Archive** | No longer actively developed or operated. Code retained, no changes. | Sunset decision ADR | (terminal) |

## Rules

1. **Monotonic forward, skips allowed.** A library may go `Setup → Pilot → Maintenance` (no Launch). A PoC may go `Setup → Pilot → Archive`. Backward transitions are illegal — a Launch→Pilot regression requires a "regression ADR" (see Edge cases).
2. **Transitions are confirmed by user declaration.** Entry signals are guidance; the transition is real only after `/state-sync` updates `PROJECT_STATE.md` (and, where required, a `/decide` ADR lands).
3. **Stage is orthogonal to Feature Phase.** A project at Stage = Pilot can still run any feature through Phases 1–6 of `WORKFLOW.md`.

## Transition obligations

| Transition | Required | Recommended |
|---|---|---|
| Setup → Pilot | `/state-sync` (header update) | Short ADR for first domain feature (optional) |
| Pilot → Launch | `/decide` ADR (**required**) + `/state-sync` + README updated for external audience | Deployment / ops procedure, SLA |
| Launch → Maintenance | `/decide` ADR (**required**) + `/state-sync` | `Out of Scope` section refreshed |
| Maintenance → Archive | `/decide` ADR (**required**) + `/state-sync` + README marked "archived" | Sunset retrospective |
| Forward skip | Destination transition's required artifacts only | — |

Setup → Pilot is frequent and low-stakes (no ADR). Skipped stages mean the stage *never applied* (a library is never in Launch; a PoC is never in Maintenance).

## Stage posture (AI default behavior)

AI sessions that read `PROJECT_STATE.md` MUST adopt the posture matching the current stage. If a user request conflicts with the stage's posture, surface the conflict and offer to either defer the request or transition the stage first.

| Stage | Default posture | Lean into | Push back on |
|---|---|---|---|
| **Setup** | Foundation-first | Build env, linter, CI, scaffolding, repo layout | Domain features before tooling exists |
| **Pilot** | Speed over rigor | Rapid prototyping, end-to-end core scenario, interface churn | Strict coverage / exhaustive edge cases / formal migration plans |
| **Launch** | Stability + backwards compatibility | Tests, migration plans, changelogs, user-impact review on every breaking change | "Just rewrite it" / "let's break the API" without migration + ADR |
| **Maintenance** | Bug fixes and refactors only | Defects, security patches, dependency upkeep, incremental polish | New features (suggest transitioning out of Maintenance first) |
| **Archive** | Read-only | Questions, archaeology, doc updates clarifying the archived state | All code changes (require Reactivation ADR returning the project to Pilot) |

These are defaults — the user can override with explicit instruction. The point is that the default matches the project's operational reality.

## Edge cases

- **Library (npm / gem / pypi):** `Setup → Pilot → Maintenance` (Launch skipped — no external operational burden).
- **PoC / learning project:** `Setup → Pilot → Archive` is normal.
- **Reactivation (Archive → active):** New ADR declaring re-entry to Pilot. `since` resets to the re-entry date; prior entry preserved in the ADR body.
- **Launch → Pilot regression (severe defect found):** Separate "regression to Pilot" ADR (not `/supersede`) — updates the stage slot.
- **Monorepo (N projects in one repo):** Out of scope — repo split recommended. The template assumes 1 repo = 1 project.
- **Bug fixes / refactors only:** No stage change. Stage tracks *operational mode*, not activity volume.

## `PROJECT_STATE.md` shape

```markdown
# PROJECT_STATE

> Lifecycle Stage: Pilot (since 2026-05-23)
> Last Updated: <ISO timestamp> by <name> (session: <slug>)
```

- Value: exactly one of `Setup`, `Pilot`, `Launch`, `Maintenance`, `Archive`.
- `since`: date the project entered the current stage. Updated only on real transitions.
- Cardinality: exactly one stage per project.
- Seed: `install.sh` initializes new projects to `Setup (since <today>)`.

## Initial labeling (projects bootstrapped before this standard)

Add the header line manually, choosing the current stage by self-assessment. A formal ADR is optional — this is *initial labeling*, not a *transition*.
````

- [ ] **Step 2: Verify line count and the file lands in the template tree**

Run: `wc -l common/docs/standards/LIFECYCLE.md && ls common/docs/standards/`
Expected: line count ≤100; directory listing includes `LIFECYCLE.md` alongside the other standards (`QUALITY.md`, `REVIEW.md`, `RULES.md`, `WORKFLOW.md`).

- [ ] **Step 3: Commit**

```bash
git add common/docs/standards/LIFECYCLE.md
git commit -m "feat(standards): add LIFECYCLE.md — project lifecycle stages standard"
```

---

### Task 5: Wire `LIFECYCLE.md` into `common/CLAUDE.md`

**Files:**
- Modify: `common/CLAUDE.md` (two tables)

- [ ] **Step 1: Add the Standards Reference row**

In `common/CLAUDE.md`, find the Standards Reference table (the table whose first row is `| Document      | Description ...`). Insert a new row immediately after the `REVIEW.md` row and before the `STACK.md` row:

```markdown
| `LIFECYCLE.md`| Project lifecycle stages (Setup → Pilot → Launch → Maintenance → Archive), transition rules |
```

Column padding should match the surrounding rows so the markdown still renders cleanly. (The existing rows pad `Document` to 13 characters; `` `LIFECYCLE.md`` already fits.)

- [ ] **Step 2: Add the Task → Required Reading row**

In the same file, find the `Task → Required Reading` table (the table whose first row is `| Task Type ... | Must Read ...`). Insert a new row at the end, after the `Code review / PR` row:

```markdown
| Lifecycle stage transition / archive decision | LIFECYCLE                                                |
```

- [ ] **Step 3: Verify**

Run: `grep -n 'LIFECYCLE' common/CLAUDE.md`
Expected: at least 2 matching lines (one in each table).

- [ ] **Step 4: Commit**

```bash
git add common/CLAUDE.md
git commit -m "feat(claude.md): reference LIFECYCLE.md in standards + task-mapping tables"
```

---

### Task 6: Declare this repo's own lifecycle stage

**Files:**
- Modify: `PROJECT_STATE.md` (this repo's root, NOT `common/PROJECT_STATE.md`)

- [ ] **Step 1: Add the Lifecycle Stage header line**

Insert a single line right after the title, before the existing `> Last Updated:` line. New header:

```markdown
# PROJECT_STATE

> Lifecycle Stage: Pilot (since 2026-05-23)
> Last Updated: <existing timestamp — leave unchanged, /state-sync will refresh it on the next sync>
```

The `since` date is `2026-05-23` — the ADR-0000 acceptance date, when the orchestrator standard was first usable. Per `LIFECYCLE.md`, this repo is in `Pilot` because the orchestrator is usable but actively expanding (e.g., this ADR-0003 is itself a Pilot-stage activity).

- [ ] **Step 2: Verify**

Run: `head -5 PROJECT_STATE.md`
Expected: title, blank line, `> Lifecycle Stage: Pilot (since 2026-05-23)`, `> Last Updated: ...`, blank line.

- [ ] **Step 3: Commit**

```bash
git add PROJECT_STATE.md
git commit -m "chore(state): declare init-project's own Lifecycle Stage = Pilot (since 2026-05-23)"
```

---

### Task 7: Add ADR-0003

**Files:**
- Create: `docs/decisions/ADR-0003-adopt-lifecycle-stages.md`

- [ ] **Step 1: Write the ADR**

Create `docs/decisions/ADR-0003-adopt-lifecycle-stages.md` with this content:

```markdown
# ADR-0003: Adopt project lifecycle stages (Setup → Pilot → Launch → Maintenance → Archive)

- **Status:** Accepted
- **Date:** 2026-05-27
- **Supersedes:** (none — extends ADR-0000)
- **Superseded by:** (none)

## Context

`WORKFLOW.md` defines a six-phase pipeline that scopes *one feature* from idea
to merged PR. It does not name a per-project lifecycle, so a contributor or AI
session reading `PROJECT_STATE.md` cannot tell at a glance whether the project
is still being set up, internally usable, in production, in maintenance, or
done. A bug fix in a still-prototyping project should be approached very
differently from the same bug fix in a launched project (deployment risk,
backwards compatibility, user-impact review), and the orchestrator surfaces
neither distinction today.

ADR-0000 introduced `PROJECT_STATE.md` as the "where are we right now"
surface. This ADR extends it with one orthogonal field that answers the
per-project question, with vocabulary common to every project bootstrapped
from this template (services, libraries, CLIs, PoCs).

## Decision

Adopt five lifecycle stages — `Setup → Pilot → Launch → Maintenance → Archive`
— defined in `common/docs/standards/LIFECYCLE.md`. Stages are monotonically
forward with forward-skips allowed (a library may skip Launch; a PoC may skip
to Archive). Backward transitions require an explicit "regression ADR".

`PROJECT_STATE.md` gains exactly one header line carrying the current value
and the entry date:

```
> Lifecycle Stage: <Stage> (since YYYY-MM-DD)
```

`install.sh` seeds new projects to `Setup (since <today>)` via a post-copy
sed substitution.

Stage is orthogonal to the per-feature Phase pipeline. A project at Stage =
Pilot can still run any feature through `WORKFLOW.md` Phase 1–6. The stage
modifies the *posture* of that work (see `LIFECYCLE.md` → Stage posture),
not its mechanics.

Transitions Pilot→Launch, Launch→Maintenance, Maintenance→Archive each
require a `/decide` ADR. Setup→Pilot is lightweight (`/state-sync` only).

No automated enforcement. The orchestrator pattern remains "warn, do not
reject" (consistent with ADR-0000 and ADR-0001). A soft-validation warning
when the stage value does not match one of the five canonical labels, and
an optional `/state-sync --stage <Stage>` flag that runs the obligation
checklist, are left as future enhancements.

## Consequences

- Positive: a fresh contributor or AI session can tell the project's
  operational posture by reading one header line.
- Positive: AI sessions adopt stage-appropriate defaults (Pilot tolerates
  technical debt and interface churn; Launch demands tests, migrations, and
  changelogs; Maintenance refuses new features; Archive is read-only). The
  label becomes load-bearing instead of decorative.
- Positive: `Pilot → Launch`, `Launch → Maintenance`, and `→ Archive`
  transitions are durably recorded as ADRs, so the project's history is
  visible in `docs/decisions/` rather than only in commit log nuance.
- Positive: forward-skip rule means libraries, CLIs, PoCs, and learning
  projects all fit the same vocabulary without forcing inapplicable stages.
- Negative: every `PROJECT_STATE.md` gains one header line. Projects
  bootstrapped before this ADR need a one-line manual edit (no automated
  migration script — the cost is one line per project, and the spec calls
  this out as deliberate).
- Negative: contributors and AI sessions now need to know one more standard
  file. Mitigated by ≤100-line `LIFECYCLE.md` and the `Task → Required
  Reading` row that only fires on transition / archive decisions.
- Neutral: no new dependencies, no enforcement layer, no `gstack` coupling.
  Works in every bootstrapped project the same way the existing orchestrator
  does.

This ADR extends ADR-0000 rather than reversing it: the orchestrator
mechanism is the same, and this decision adds one orthogonal slot.
```

- [ ] **Step 2: Verify**

Run: `ls docs/decisions/`
Expected: includes `ADR-0003-adopt-lifecycle-stages.md` alongside ADR-0000/0001/0002.

- [ ] **Step 3: Commit**

```bash
git add docs/decisions/ADR-0003-adopt-lifecycle-stages.md
git commit -m "docs(adr): ADR-0003 adopt project lifecycle stages"
```

---

### Task 8: Update ADR index

**Files:**
- Modify: `docs/decisions/README.md` (the index table)

- [ ] **Step 1: Add the index row**

In `docs/decisions/README.md`, find the index table (the table whose first row is `| # | Title | Status | Date |`). Append a new row after the ADR-0002 row:

```markdown
| 0003 | Adopt project lifecycle stages (Setup → Pilot → Launch → Maintenance → Archive) | Accepted | 2026-05-27 |
```

- [ ] **Step 2: Verify**

Run: `grep -c '^| 000' docs/decisions/README.md`
Expected: `4` (ADR-0000, 0001, 0002, 0003).

- [ ] **Step 3: Commit**

```bash
git add docs/decisions/README.md
git commit -m "docs(adr): index ADR-0003"
```

---

### Task 9: Reference ADR-0003 from this repo's `PROJECT_STATE.md` Locked Decisions

**Files:**
- Modify: `PROJECT_STATE.md` (this repo's root) — `## Locked Decisions` section

- [ ] **Step 1: Add the pointer line**

In `PROJECT_STATE.md`, find the `## Locked Decisions` section. Append after the existing ADR-0002 line:

```markdown
- ADR-0003 — Adopt project lifecycle stages (Setup → Pilot → Launch → Maintenance → Archive) (Accepted, 2026-05-27)
```

- [ ] **Step 2: Verify**

Run: `grep -A 6 'Locked Decisions' PROJECT_STATE.md`
Expected: four ADR pointer lines (0000, 0001, 0002, 0003).

- [ ] **Step 3: Commit**

```bash
git add PROJECT_STATE.md
git commit -m "chore(state): record ADR-0003 in Locked Decisions"
```

---

### Task 10: Final verification

**Files:** none modified — verification only.

- [ ] **Step 1: Run the default test tier**

Run: `tests/run_all.sh 2>&1 | tail -15`
Expected: `failed: 0`. (Default tier excludes smoke and e2e.)

- [ ] **Step 2: Run smoke**

Run: `RUN_SMOKE=1 tests/run_all.sh 2>&1 | tail -20`
Expected: `failed: 0`. `smoke_empty.sh` includes the new Lifecycle Stage assertion and passes.

- [ ] **Step 3: Sanity-check that an e2e run still passes (toolchain-permitting)**

Run: `RUN_E2E=1 STRICT=0 tests/run_all.sh 2>&1 | tail -20`
Expected: `failed: 0`. (Languages whose toolchain is absent will SKIP, which is fine. We are not asserting e2e content — only that the install path remains stable.)

- [ ] **Step 4: Verify the spec → plan trace is complete**

Run: `git log --oneline -12`
Expected (most recent first): the 9 task commits above plus the two spec commits already on `main`. The ADR-0003 commit precedes the index commit precedes the PROJECT_STATE Locked-Decisions update.

- [ ] **Step 5: No final commit — verification only.**

If any step fails, return to the corresponding task and resolve before declaring the plan complete.

---

## Self-review checklist (for the implementer at the end)

After Task 10 completes, confirm:

1. `common/PROJECT_STATE.md` contains the `YYYY-MM-DD` placeholder (template literal).
2. `install.sh` runs against a fresh sandbox and the resulting `PROJECT_STATE.md` has today's date in the seeded line.
3. `common/docs/standards/LIFECYCLE.md` is ≤100 lines and covers all sections of the spec (Stages, Rules, Transitions, Posture, Edge cases, Shape, Initial labeling).
4. `common/CLAUDE.md` has both new rows; `grep -c LIFECYCLE common/CLAUDE.md` ≥ 2.
5. This repo's `PROJECT_STATE.md` header carries `Lifecycle Stage: Pilot (since 2026-05-23)` and its Locked Decisions section lists ADR-0003.
6. `docs/decisions/README.md` and `docs/decisions/ADR-0003-adopt-lifecycle-stages.md` are both present and internally consistent.
7. `tests/run_all.sh` (default tier) and `RUN_SMOKE=1 tests/run_all.sh` both report `failed: 0`.
