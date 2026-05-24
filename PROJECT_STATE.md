# PROJECT_STATE

> Last Updated: 2026-05-24T20:00:00+09:00 by Tonny Donghwi Kim (session: e2e-sandbox-shipped)

## Current Phase
(none — between cycles; e2e sandbox suite shipped and the two regressions it
caught were resolved by gitignore fix + ADR-0002)

## Locked Decisions
See `docs/decisions/README.md` for the full index.

- ADR-0000 — Adopt PROJECT_STATE + ADR + Hooks orchestrator (Accepted, 2026-05-23)
- ADR-0001 — Quality gates owned by pre-commit + CI (Accepted, 2026-05-24)
- ADR-0002 — Rails pre-commit tolerates missing rubocop gem and excludes `.enc` (Accepted, 2026-05-24)

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
