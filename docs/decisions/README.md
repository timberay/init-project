# Architecture Decision Records

Append-only log. Each ADR captures one decision: what was decided, why, and the consequences.

## Authoring

- `/decide` — draft a new ADR from conversation context
- `/supersede ADR-NNNN` — reverse a previously accepted ADR

## Rules

- Numbering is monotonic from `0000`. Never reused, never renumbered.
- `Accepted` ADRs are immutable. To reverse one, run `/supersede`.
- The only post-acceptance edit allowed is updating the `Status:` header to `Superseded by ADR-XXXX`.

## Index

| # | Title | Status | Date |
|---|-------|--------|------|
| 0000 | Adopt PROJECT_STATE + ADR + Hooks orchestrator | Accepted | 2026-05-23 |
| 0001 | Quality gates owned by pre-commit + CI | Accepted | 2026-05-24 |
| 0002 | Rails pre-commit hook tolerates missing rubocop gem and excludes encrypted credentials | Accepted | 2026-05-24 |
| 0003 | Adopt project lifecycle stages (Setup → Pilot → Launch → Maintenance → Archive) | Accepted | 2026-05-27 |
