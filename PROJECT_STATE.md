# PROJECT_STATE

> Lifecycle Stage: Pilot (since 2026-05-23)
> Last Updated: 2026-05-27T19:03:56+09:00 by Tonny Donghwi Kim (session: lifecycle-followups-shipped)

## Current Phase
(none — between cycles; lifecycle stages follow-ups shipped:
smoke assertions across all language overlays, `/state-sync --stage` flow
with canonical-label soft-validation, WORKFLOW/README cross-references to
LIFECYCLE.md, `--force` reset behavior documented, and a simplification
pass pointing `/state-sync` at LIFECYCLE.md as obligations source of truth.)

## Locked Decisions
See `docs/decisions/README.md` for the full index.

- ADR-0000 — Adopt PROJECT_STATE + ADR + Hooks orchestrator (Accepted, 2026-05-23)
- ADR-0001 — Quality gates owned by pre-commit + CI (Accepted, 2026-05-24)
- ADR-0002 — Rails pre-commit tolerates missing rubocop gem and excludes `.enc` (Accepted, 2026-05-24)
- ADR-0003 — Adopt project lifecycle stages (Setup → Pilot → Launch → Maintenance → Archive) (Accepted, 2026-05-27)

## Active Work
(none)

## Open Questions
(none)

## Out of Scope
- Multi-team approval workflows
- Hard pre-commit blocks for orchestrator immutability (quality-gate pre-commit per ADR-0001 is a different layer)
- Bringing Phase 1 / Phase 2 raw outputs in-repo (only decisions extracted to ADRs)

## Last Updated
(see header)
