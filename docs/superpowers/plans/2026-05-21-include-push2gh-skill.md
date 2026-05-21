# Include push2gh as a Project Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle the `push2gh` skill into the multi-language base template so that every new project gets `<project>/.claude/skills/push2gh/SKILL.md` installed automatically by `install.sh`.

**Architecture:** `push2gh` is a single-file skill (`SKILL.md` with YAML frontmatter + Markdown body). It is language-neutral, so it belongs in `common/.claude/skills/push2gh/`. The existing `lib/copy-files.sh` already walks every file under `common/` and copies it into the target (only `.claude/settings.json` is skipped because phase 4 merges it). No installer code changes are needed — only file additions and documentation.

**Tech Stack:** None new. Bash + `cp` (via the existing `copy-files.sh` module).

**Reference:** Global source is `~/.claude/skills/push2gh/SKILL.md` (13 KB, ~370 lines). The plan does **not** modify or auto-sync the global file; the template's copy is a snapshot taken at the moment of Task 1.

---

## File Map

### Created (new)
- `common/.claude/skills/push2gh/SKILL.md` — copy of the current global skill body (verbatim from `~/.claude/skills/push2gh/SKILL.md`)
- (No new code files. No new test files — existing smoke tests are extended.)

### Modified
- `common/docs/standards/WORKFLOW.md` — phase 6 gets a "Without gstack" callout that points at `/push2gh` as the substitute for `/ship` + `/land-and-deploy`
- `common/CLAUDE.md` — "Recommended Claude Code Plugins" section grows a new sub-table for "bundled project skills" listing push2gh
- `README.md` — same addition under the recommended-plugins section
- `docs/USAGE.md` — section 9 (Recommended Claude Code plugins) grows a new sub-table for bundled project skills; section 8 (What you get) adds `.claude/skills/push2gh/SKILL.md` to the file tree
- `tests/smoke_rails.sh`, `tests/smoke_python.sh`, `tests/smoke_go.sh`, `tests/smoke_empty.sh` — each adds one assertion that `<target>/.claude/skills/push2gh/SKILL.md` exists and starts with the `---\nname: push2gh` frontmatter

### Untouched
- `install.sh`, `lib/*.sh`, `langs/*/` overlays — the existing copy-files behavior is sufficient

---

## Task 1: Snapshot the global push2gh skill into the template

**Files:**
- Create: `common/.claude/skills/push2gh/SKILL.md`

- [ ] **Step 1: Verify the source exists and is readable**

```bash
test -f /home/tonny/.claude/skills/push2gh/SKILL.md && echo "source OK"
head -3 /home/tonny/.claude/skills/push2gh/SKILL.md
```

Expected: `source OK` and the first three lines should be:

```
---
name: push2gh
description: >
```

If either fails, STOP and report BLOCKED.

- [ ] **Step 2: Create the destination directory and copy the file**

```bash
cd /home/tonny/projects/00.base-files
mkdir -p common/.claude/skills/push2gh
cp /home/tonny/.claude/skills/push2gh/SKILL.md common/.claude/skills/push2gh/SKILL.md
```

- [ ] **Step 3: Verify byte-for-byte equivalence with the source**

```bash
cd /home/tonny/projects/00.base-files
diff /home/tonny/.claude/skills/push2gh/SKILL.md common/.claude/skills/push2gh/SKILL.md && echo "identical"
wc -c common/.claude/skills/push2gh/SKILL.md
```

Expected: `identical` and a non-zero byte count (~13 KB).

- [ ] **Step 4: Commit**

```bash
cd /home/tonny/projects/00.base-files
git add common/.claude/skills/push2gh/SKILL.md
git commit -m "feat(common): bundle push2gh skill as project-level skill

Snapshots ~/.claude/skills/push2gh/SKILL.md into the template so every
new project gets .claude/skills/push2gh/SKILL.md installed by
copy-files.sh. The skill is language-neutral and lives under the common
core, alongside the existing graphify + pipeline-reminder hooks."
```

---

## Task 2: Add push2gh assertion to the four smoke tests

**Files:**
- Modify: `tests/smoke_rails.sh`
- Modify: `tests/smoke_python.sh`
- Modify: `tests/smoke_go.sh`
- Modify: `tests/smoke_empty.sh`

Each smoke test currently has a "real run" section that runs `install.sh --force --skip-skills` against a temp dir and then asserts on the placed files. Add one additional assertion in each: confirm `<target>/.claude/skills/push2gh/SKILL.md` exists and has the expected frontmatter.

- [ ] **Step 1: Patch `tests/smoke_rails.sh`**

Find this block (it's near the end of the real-run section):

```
jq -e '.hooks.PreToolUse | length >= 2' "$TMP/.claude/settings.json" >/dev/null \
  || fail "merged settings.json should have at least 2 PreToolUse entries"
ok "real run installs rails overlay"
```

Insert two new lines immediately BEFORE the `ok "real run installs rails overlay"` line:

```
[[ -f "$TMP/.claude/skills/push2gh/SKILL.md" ]] || fail "push2gh skill not installed"
head -2 "$TMP/.claude/skills/push2gh/SKILL.md" | grep -q "name: push2gh" || fail "push2gh SKILL.md missing expected frontmatter"
ok "push2gh skill bundled"
```

So the final order is: existing PreToolUse assertion → new push2gh existence assertion → new push2gh frontmatter assertion → `ok "push2gh skill bundled"` → `ok "real run installs rails overlay"` → `echo "smoke_rails.sh: ALL PASS"`.

- [ ] **Step 2: Patch `tests/smoke_python.sh`**

Same pattern. Find the existing assertion line:

```
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("ruff")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference ruff"
ok "real run installs python overlay"
```

Insert the SAME three new lines BEFORE the `ok "real run installs python overlay"` line:

```
[[ -f "$TMP/.claude/skills/push2gh/SKILL.md" ]] || fail "push2gh skill not installed"
head -2 "$TMP/.claude/skills/push2gh/SKILL.md" | grep -q "name: push2gh" || fail "push2gh SKILL.md missing expected frontmatter"
ok "push2gh skill bundled"
```

- [ ] **Step 3: Patch `tests/smoke_go.sh`**

Same pattern. Find:

```
jq -e '.hooks.PostToolUse[0].hooks[0].command | contains("gofmt")' "$TMP/.claude/settings.json" >/dev/null \
  || fail "PostToolUse hook should reference gofmt"
ok "real run installs go overlay"
```

Insert the three new lines BEFORE `ok "real run installs go overlay"`.

- [ ] **Step 4: Patch `tests/smoke_empty.sh`**

Find the last assertion in the "--lang go" path:

```
grep -q "Go" "$TMP/docs/standards/STACK.md" || fail "Go overlay not applied"
ok "--lang override works in empty dir"
```

Insert the three new lines BEFORE `ok "--lang override works in empty dir"`.

- [ ] **Step 5: Run the smoke suite**

```bash
cd /home/tonny/projects/00.base-files
RUN_SMOKE=1 ./tests/run_all.sh
```

Expected summary line: `passed: 10 / failed: 0`. All four smoke tests must now have an additional `ok: push2gh skill bundled` line in their output.

If anything fails, STOP and report BLOCKED.

- [ ] **Step 6: Commit**

```bash
git add tests/smoke_rails.sh tests/smoke_python.sh tests/smoke_go.sh tests/smoke_empty.sh
git commit -m "test(smoke): assert push2gh skill is bundled in every overlay"
```

---

## Task 3: Add push2gh callout to WORKFLOW.md phase 6

**Files:**
- Modify: `common/docs/standards/WORKFLOW.md`

- [ ] **Step 1: Edit phase 6**

Find this block in `common/docs/standards/WORKFLOW.md` (around line 42):

```
#### Phase 6 — Review → Ship → Deploy → Document
Run in this order; each gates the next:

1. `/review` — pre-landing diff review against base branch
2. `/ship` — run tests, bump version, create PR
3. `/land-and-deploy` — merge, deploy, verify production health
4. `/document-release` — sync README / CLAUDE.md / standards with what shipped
```

Insert a new sub-block immediately AFTER step 4 (and BEFORE the `### Phase continuation rules` heading):

```

**Without gstack.** When `/ship` and `/land-and-deploy` are unavailable
(gstack not installed in the current environment), substitute the bundled
**`/push2gh`** project skill — it covers the commit → push → PR → optional
automerge → cleanup arc. It is language-neutral and is installed at
`.claude/skills/push2gh/SKILL.md` by `install.sh`. `/review` and
`/document-release` still need manual substitutes (a careful diff read and
a manual README/CHANGELOG sync respectively).
```

- [ ] **Step 2: Verify the file still parses cleanly**

```bash
cd /home/tonny/projects/00.base-files
# No tooling here other than visual scan, but confirm grep finds the new heading
grep -n "Without gstack" common/docs/standards/WORKFLOW.md
grep -n "/push2gh" common/docs/standards/WORKFLOW.md
```

Expected: each grep returns exactly one matching line.

- [ ] **Step 3: Commit**

```bash
git add common/docs/standards/WORKFLOW.md
git commit -m "docs(workflow): document /push2gh as gstack-free phase 6 substitute"
```

---

## Task 4: Add push2gh row to recommended-skills tables

Three documents have a "recommended plugins" section that already lists `graphify` and `gstack`. Add a new sub-section for "Bundled project skills" listing `push2gh`.

**Files:**
- Modify: `common/CLAUDE.md`
- Modify: `README.md`
- Modify: `docs/USAGE.md`

- [ ] **Step 1: Update `common/CLAUDE.md`**

Find the existing block at the bottom of the file:

```
| Plugin                       | Marketplace                | Purpose                                      |
|------------------------------|----------------------------|----------------------------------------------|
| `superpowers`                | `claude-plugins-official`  | Brainstorming, plans, TDD, debugging, review |
| `code-review`                | `claude-plugins-official`  | Branch / PR review                           |
| `andrej-karpathy-skills`     | `karpathy-skills`          | Karpathy's coding-mistake guardrails         |

`graphify` and `gstack` are **verified, not installed** by the installer (it
checks `~/.claude/skills/<name>/` and warns if absent). `gstack` is required for
`WORKFLOW.md` phases 1, 2, and 6 (`/office-hours`, `/plan-eng-review`,
`/review`, `/ship`, `/land-and-deploy`, `/document-release`). Install them
manually if missing.
```

Append a new paragraph immediately AFTER the "Install them manually if missing." line:

```

### Bundled project skills

The installer also copies the following skill straight into
`.claude/skills/<name>/` so it lives inside the project's git history:

| Skill      | Purpose                                                                   |
|------------|---------------------------------------------------------------------------|
| `push2gh`  | Adaptive commit → push → PR → optional automerge → cleanup. Use as a `gstack`-free substitute for `/ship` + `/land-and-deploy` in `WORKFLOW.md` phase 6. |

The bundled copy is a snapshot of the global `~/.claude/skills/push2gh/`
taken at template build time. To upgrade, copy the latest file back into
the template (`cp ~/.claude/skills/push2gh/SKILL.md
~/projects/00.base-files/common/.claude/skills/push2gh/SKILL.md`) and
commit.
```

- [ ] **Step 2: Update `README.md`**

Find the existing block:

```
| Plugin                    | Marketplace                               | Purpose                                |
|---------------------------|-------------------------------------------|----------------------------------------|
| `superpowers`             | `anthropics/claude-plugins-official`      | Brainstorm / plan / TDD / debug / review |
| `code-review`             | `anthropics/claude-plugins-official`      | Branch / PR review                     |
| `andrej-karpathy-skills`  | `forrestchang/andrej-karpathy-skills`     | Karpathy coding guardrails             |

`graphify` and `gstack` are **verified** (not installed) by the installer —
both live outside the claude plugin marketplaces. `gstack` is referenced by
`WORKFLOW.md` phases 1, 2, and 6; install it manually if you want the full
pipeline. Without it, those phases need manual substitutes.
```

Append a new section AFTER that paragraph:

```

### Bundled project skills (installed into the project itself)

| Skill      | Where it lands                              | Purpose                                                              |
|------------|---------------------------------------------|----------------------------------------------------------------------|
| `push2gh`  | `<project>/.claude/skills/push2gh/SKILL.md` | Commit → push → PR → optional automerge → cleanup. `gstack`-free phase 6 substitute. |

Bundled skills are snapshots committed into this template. They are upgraded
manually — see `docs/USAGE.md` for the resync procedure.
```

- [ ] **Step 3: Update `docs/USAGE.md`**

(a) In section 8 ("What you get"), find the file-tree block and add the new path. Find:

```
└── .claude/
    ├── settings.json                  # Merged hook config: graphify reminder + pipeline reminder +
    │                                  #   pre-commit (test runner + linter) + post-Write/Edit auto-format
    └── hooks/
        └── pipeline-reminder.txt      # Context injected by the UserPromptSubmit hook
```

Replace it with:

```
└── .claude/
    ├── settings.json                  # Merged hook config: graphify reminder + pipeline reminder +
    │                                  #   pre-commit (test runner + linter) + post-Write/Edit auto-format
    ├── hooks/
    │   └── pipeline-reminder.txt      # Context injected by the UserPromptSubmit hook
    └── skills/
        └── push2gh/
            └── SKILL.md               # Project-bundled skill: commit → push → PR → cleanup
```

(b) In section 9 ("Recommended Claude Code plugins"), find the existing "verified, not installed" table and append a new sub-section AFTER the paragraph that ends with "manual product / architecture / release notes in place of the missing skills.":

```

### Bundled project skills

The installer also lands the following skill directly into
`<project>/.claude/skills/<name>/` — these live inside your project's git
history (no global `~/.claude/skills/` dependency):

| Skill      | Where it lands                              | Purpose                                                                       |
|------------|---------------------------------------------|-------------------------------------------------------------------------------|
| `push2gh`  | `<project>/.claude/skills/push2gh/SKILL.md` | Commit → push → PR → optional automerge → cleanup. Use as a `gstack`-free substitute for `/ship` + `/land-and-deploy` in `WORKFLOW.md` phase 6. |

**Updating bundled skills.** Bundled skill bodies are **snapshots** taken
when the template was built. To pull a newer copy from your global skills
directory:

```bash
cp ~/.claude/skills/push2gh/SKILL.md \
   ~/projects/00.base-files/common/.claude/skills/push2gh/SKILL.md

cd ~/projects/00.base-files
git diff common/.claude/skills/push2gh/SKILL.md      # review the delta
git add common/.claude/skills/push2gh/SKILL.md
git commit -m "chore: refresh push2gh skill snapshot"
git push
```

Downstream projects pick up the new snapshot the next time they run
`install.sh --force`.
```

- [ ] **Step 4: Commit all three files together**

```bash
cd /home/tonny/projects/00.base-files
git add common/CLAUDE.md README.md docs/USAGE.md
git commit -m "docs: document push2gh as a bundled project skill

Adds a 'Bundled project skills' sub-section to common/CLAUDE.md,
README.md, and docs/USAGE.md describing push2gh. USAGE.md also adds
the installed file path to the 'What you get' tree and documents the
resync procedure (cp from ~/.claude/skills/push2gh/SKILL.md + commit)."
```

---

## Task 5: Push everything to origin

- [ ] **Step 1: Sanity sweep — full test run on the final state**

```bash
cd /home/tonny/projects/00.base-files
RUN_SMOKE=1 ./tests/run_all.sh
```

Expected: `passed: 10 / failed: 0`. If anything fails, STOP and report BLOCKED.

- [ ] **Step 2: Verify the log**

```bash
git log --oneline -6
git status --short
```

Expected: four new commits at the top (Tasks 1–4); working tree clean.

- [ ] **Step 3: Push**

```bash
git push origin main
```

Expected: `<old SHA>..<new SHA>  main -> main`.

- [ ] **Step 4: Final smoke check from a fresh tmp dir**

```bash
TMP="$(mktemp -d)"
touch "$TMP/Gemfile"
( cd "$TMP" && /home/tonny/projects/00.base-files/install.sh --force --skip-skills >/dev/null )
test -f "$TMP/.claude/skills/push2gh/SKILL.md" && echo "push2gh installed OK"
rm -rf "$TMP"
```

Expected: `push2gh installed OK`.

---

## Self-Review

After the implementation, re-check this plan against the goal:

1. **Goal achieved?** Every new project bootstrapped via `install.sh` now has `.claude/skills/push2gh/SKILL.md`. Confirmed by Task 5 Step 4.

2. **No installer code changes?** Verified — Tasks 1–4 only touch content files, not `install.sh` or `lib/*.sh`. The existing `copy-files.sh` walks every file under `common/` and copies it without special-casing skills.

3. **WORKFLOW.md remains gstack-friendly?** Yes — the new callout is additive (Phase 6 still lists `/ship` and `/land-and-deploy` first; push2gh is the substitute, not the replacement).

4. **Backwards compatible?** Yes — existing projects re-running `install.sh --force` will simply gain a new file (and back up any pre-existing `<project>/.claude/skills/push2gh/SKILL.md` with the standard timestamp suffix).

5. **Snapshot freshness?** Acknowledged in USAGE.md — the resync procedure is documented; there is no automatic re-pull from `~/.claude/`.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-21-include-push2gh-skill.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Fresh subagent per task, automatic review between tasks.

**2. Inline Execution** — Execute the five tasks in this session sequentially.

Which approach do you prefer? Or do you want to review the plan first?
