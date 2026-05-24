# PROJECT_STATE

> Last Updated: 2026-05-24T19:30:00+09:00 by Tonny Donghwi Kim (session: e2e-sandbox-bringup)

## Current Phase
Validating bootstrap on real-framework sandboxes (rails new / uv init / go mod init)
before applying base-files to a new project.

## Locked Decisions
See `docs/decisions/README.md` for the full index.

- ADR-0000 — Adopt PROJECT_STATE + ADR + Hooks orchestrator (Accepted, 2026-05-23)
- ADR-0001 — Quality gates owned by pre-commit + CI (Accepted, 2026-05-24)

## Active Work
- `tests/e2e_{rails,python,go}.sh` + `RUN_E2E=1` branch in `run_all.sh`
  drive a fresh framework project end-to-end (init → install.sh → pre-commit
  install → first commit → intentional violation → fix → drift hook).
- Fixed: `langs/python/.gitignore` trailing whitespace (caught by e2e_python.sh,
  was breaking the ADR-0001 bootstrap-commit invariant).

## Open Questions
- **Rails rubocop hook vs `bundle install` ordering** — caught by e2e_rails.sh.
  `langs/rails/.pre-commit-config.yaml` invokes `bundle exec rubocop` as a
  system hook; after `rails new --skip-bundle` the gem is absent, so the
  first commit fails with `can't find executable rubocop`. This violates the
  ADR-0001 invariant "bootstrap commit must succeed" *unless* the user runs
  `bundle install` between `install.sh` and `pre-commit install`. Options
  (decide via `/decide` → ADR-0002):
  1. Soften the hook (e.g., `bundle exec rubocop 2>/dev/null || true`, or
     `stages: [manual]`) so missing gems do not block bootstrap.
  2. Document the required order in `README.md` Quick Start and add
     `bundle install` to `e2e_rails.sh`.
  3. Redefine the ADR-0001 invariant to include `bundle install` as part of
     "bootstrap" (i.e., the invariant covers framework-native init plus
     dependency resolution, not just `install.sh`).
  Until decided, `e2e_rails.sh` is expected to FAIL when `RUN_E2E=1` is set
  — that failure is the open-question signal, not a regression.

## Out of Scope
- Multi-team approval workflows
- Hard pre-commit blocks for orchestrator immutability (quality-gate pre-commit per ADR-0001 is a different layer)
- Bringing Phase 1 / Phase 2 raw outputs in-repo (only decisions extracted to ADRs)

## Last Updated
(see header)
