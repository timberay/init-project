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
