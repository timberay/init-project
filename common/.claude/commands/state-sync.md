---
name: state-sync
description: Refresh PROJECT_STATE.md to reflect current session activity. AI proposes a diff; user approves before save.
---

You are syncing `PROJECT_STATE.md` — the project's "where are we right now" page.

## Steps

1. **Read the current state.**
   Read `PROJECT_STATE.md`. If it doesn't exist, create a stub with these six sections (all empty bodies except headers and a "Last Updated: never" line):

   ```markdown
   # PROJECT_STATE

   > Last Updated: never

   ## Current Phase
   (none)

   ## Locked Decisions
   See `docs/decisions/README.md`.

   ## Active Work
   (none)

   ## Open Questions
   (none)

   ## Out of Scope
   (none)

   ## Last Updated
   (see header)
   ```

2. **Survey current activity.** Gather facts:
   - `git log --oneline -10` for recent commits
   - `git status` for uncommitted changes
   - Files mentioned/edited in the current conversation
   - Active spec/plan files: `ls docs/superpowers/specs/ docs/superpowers/plans/` if they exist
   - Latest ADR (from `docs/decisions/README.md`)

3. **Propose updates to each section:**
   - **Current Phase:** Which of the 6 pipeline phases is active (see `docs/standards/WORKFLOW.md`). Include the active spec/plan paths if any.
   - **Locked Decisions:** Only update if a new ADR became `Accepted` since the last sync. Otherwise leave alone.
   - **Active Work:** In-progress items, one bullet each, ≤80 chars. If a previously active item shipped, remove it.
   - **Open Questions:** Pending decisions surfaced in the conversation that haven't been resolved.
   - **Out of Scope:** Items the user explicitly said no to.

4. **Show the proposed new PROJECT_STATE.md to the user.** Ask:
   > "Proposed PROJECT_STATE.md above. Approve, edit, or cancel?"

5. **On approval:**
   - Update the `Last Updated` header line:
     ```
     > Last Updated: <ISO 8601 timestamp, e.g. 2026-05-23T14:00:00+09:00> by <git config user.name> (session: <brief-tag>)
     ```
     The session tag is a short kebab-case label (e.g. `orchestrator-design`).
   - Write the file.

6. **Stage. Do not commit.**
   Run: `git add PROJECT_STATE.md`. Tell the user.

## Rules

- Hard cap: PROJECT_STATE.md must stay under 100 lines. If a section grows too long, that content belongs in an ADR or spec — link to it instead.
- Never write decision reasoning into PROJECT_STATE.md. Reasoning lives in ADRs.
- If `git config user.name` is empty, use `unknown`.
