# PROJECT_STATE

> Lifecycle Stage: Pilot (since 2026-05-23)
> Last Updated: 2026-05-27T16:59:00+09:00 by Tonny Donghwi Kim (session: lifecycle-stages-shipped)

## Current Phase
(none — between cycles; project lifecycle stages standard shipped:
ADR-0003 + LIFECYCLE.md + PROJECT_STATE.md header slot + install.sh seed.
`.antigravitycli/` now gitignored.)

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
