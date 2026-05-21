---
name: push2gh
description: >
  Takes local changes on a feature branch and gets them into the default branch
  via the PR flow — commit, push, create/update PR, optionally add automerge
  label, and clean up local state after merge. Adapts to the repo's protection
  rules: uses direct-push when the default branch allows it, uses PR flow when
  protected. Triggered by "push changes", "upload to github", "commit and push",
  "push to main", or "git push".
---

# push2gh — Adaptive Git-to-GitHub Skill

End goal: **local feature work ends up merged into the default branch on both remote and local**, via the path the repo's protection rules actually allow.

Three things this skill does not do:

- **Never** `gh pr merge --admin` (bypassing required checks).
- **Never** `git push --force` / `--force-with-lease` on a branch the user didn't explicitly ask to rewrite.
- **Never** delete branches with unmerged content.

When in doubt, stop and ask.

---

## Phase 0 — Pre-flight

Run all checks before any state change.

```bash
git rev-parse --is-inside-work-tree   # must be true
git remote -v                         # origin must exist
git branch --show-current             # capture current branch
git status --short                    # capture dirty state
```

**Abort conditions:**

- Not a git repo → instruct user to `git init` or `cd` into the right path.
- No `origin` remote → ask for the URL, then `git remote add origin <URL>`.
- Detached HEAD → warn and require user confirmation before continuing.
- `.git/MERGE_HEAD` or `.git/rebase-merge` exists → an incomplete merge/rebase; ask user to resolve first.

### Detect the default branch (do NOT hard-code `main`)

```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null \
                  || git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's|^origin/||' \
                  || echo main)
```

### Detect branch protection (adaptive)

```bash
# Returns 200 + JSON if protected, 404 if not.
gh api "repos/{owner}/{repo}/branches/$DEFAULT_BRANCH/protection" --silent 2>/dev/null
```

Classify the repo:

| `protection` | `automerge.yml` workflow present | Flow |
|---|---|---|
| Yes | Yes | **PR + automerge label** (Flow A) |
| Yes | No | **PR + manual `gh pr merge --auto`** (Flow B) |
| No | Yes | **PR + automerge label** (Flow A) — even without protection, the automerge workflow signals the team uses PR-based merges |
| No | No | **Direct push** (Flow C) |

Detect automerge workflow:

```bash
test -f .github/workflows/automerge.yml \
  && grep -q "automerge" .github/workflows/automerge.yml
```

### Branch context

- On the default branch? → In Flow A/B, refuse to push directly. Offer to create a feature branch from the staged changes:
  ```bash
  git checkout -b <suggested-branch-name>
  ```
- On a feature branch? → Proceed.

### Fast-path: "nothing to do but clean up"

Before running Phase 1, check whether this invocation is really a **post-merge cleanup call** rather than a fresh push:

```bash
# 1. Nothing uncommitted AND nothing unpushed
[ -z "$(git status --porcelain)" ] \
  && [ -z "$(git log --oneline @{u}..HEAD 2>/dev/null)" ] \
  || skip_cleanup=yes

# 2. Current branch's PR is already MERGED
gh pr list --head "$(git branch --show-current)" --state merged --json number -q '.[0].number'

# 3. OR there are local branches whose PRs are MERGED that haven't been deleted yet
for b in $(git branch --format='%(refname:short)' | grep -v "^$DEFAULT_BRANCH$"); do
  gh pr list --head "$b" --state merged --json number -q '.[0].number'
done
```

If these conditions describe the situation → **skip Phases 1–4 entirely and jump to Phase 5 (post-merge cleanup).** Announce: *"No new work to push. Detected merged PR(s) — proceeding to local cleanup."*

---

## Phase 1 — Commit (shared by all flows)

### 1.1 Analyze changes

```bash
git status --short
git diff --stat HEAD
# Only dump full diff if it fits (<500 lines); else summarize by file.
```

If there is **nothing to commit** and the branch is already at origin, skip to Phase 2 directly (there may still be a PR to open or clean up).

### 1.2 Security scan (blocking)

```bash
# Scan staged + unstaged + untracked for common secret patterns
git diff HEAD | grep -iE "(api_key|secret|password|token|private_key|AWS_|GITHUB_TOKEN|BEGIN (RSA|EC|OPENSSH|PGP))"
git ls-files --others --exclude-standard | xargs -r grep -liE "(api_key|secret|password|private_key)" 2>/dev/null
git status --short | awk '{print $2}' | grep -iE '(\.env(\..*)?$|\.pem$|\.key$|id_rsa|credentials\.json)'
```

If any hit → **abort immediately**, show the file/line, suggest `.gitignore` or `git rm --cached`. Do not auto-commit secrets away; let the user decide.

### 1.3 Generate commit message (Conventional Commits)

```
<type>(<scope>): <subject in imperative, ≤72 chars>

<body: WHY this change, not WHAT the diff shows>
```

| type | When |
|---|---|
| feat | new user-visible capability |
| fix | bug fix |
| refactor | code change with no behavior change |
| docs | documentation only |
| test | test-only change |
| chore | build, CI, tooling, deps |
| style | formatting only |
| perf | performance improvement |

- Scope = module/package/directory affected; omit if global.
- Follow the project's recent `git log --oneline -20` style if it diverges.
- Do NOT bundle unrelated changes. If the diff spans multiple concerns, **stop and ask** before committing.

### 1.4 Stage and commit

```bash
git add -A                    # or explicit paths if only part should be committed
git commit -m "$(cat <<'EOF'
<generated message>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If a pre-commit hook fails → fix the underlying issue (rubocop, lint, tests) and create a **new** commit. Never use `--no-verify`, never `--amend` silently.

---

## Phase 2 — Flow A: PR + automerge label

Use when `.github/workflows/automerge.yml` is present (with or without branch protection — the workflow handles the merge once CI passes and the `automerge` label is set).

### 2A.1 Push the feature branch

```bash
git push -u origin "$(git branch --show-current)"
```

### 2A.2 Create or update the PR

```bash
# Check if a PR already exists for this head branch
gh pr list --head "$(git branch --show-current)" --state open --json number -q '.[0].number'
```

If none: create one. Title = the most recent commit's subject (or a summary of all commits on the branch if multiple). Body template:

```markdown
## Summary
- <one bullet per commit, concise>

## Test plan
- [ ] <what to verify manually or automatically>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

```bash
gh pr create --base "$DEFAULT_BRANCH" --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

If a PR exists and the commits have changed materially, optionally update the body (`gh pr edit <N> --body ...`). Do not rewrite user-authored PR descriptions without asking.

### 2A.3 Automerge label (user-confirmed)

Ask the user: **"Apply `automerge` label? (checks will gate; `needs-human-review` label blocks it.)"**

If yes:

```bash
# Refuse if needs-human-review is present
if gh pr view "$PR" --json labels -q '.labels[].name' | grep -qx 'needs-human-review'; then
  echo "needs-human-review is set — skipping automerge."
else
  gh pr edit "$PR" --add-label automerge
fi
```

### 2A.4 Report and stop — do not wait for merge

After the label is applied (or skipped), report the PR URL and stop. Do not poll for merge completion.

Append the following hint to the final summary so the user knows what to do next:

> **Phase 1 done.** Once CI passes and the PR is auto-merged, run `/push2gh` again — the skill will detect the merged state and perform local cleanup (pull main, delete merged feature branch). Nothing to do in between.

Only if the user *explicitly* asks to wait on this invocation:

```bash
# Single check (do NOT poll aggressively)
gh pr view "$PR" --json state,statusCheckRollup
```

Use a sparse monitor (≥60s interval). Never busy-loop. Default is always "report and stop".

---

## Phase 3 — Flow B: PR + manual auto-merge

Default branch protected, no automerge workflow. Same as Flow A through 2A.2, then instead of labeling:

```bash
# Queues the merge once checks pass; --admin is forbidden
gh pr merge "$PR" --auto --squash --delete-branch
```

If the user wants to merge immediately after checks pass without queuing, they can run `gh pr merge $PR --squash --delete-branch` themselves — do not attempt it on their behalf without explicit consent.

---

## Phase 4 — Flow C: Direct push (unprotected default branch)

Used only when `gh api .../protection` returned 404 **and** no `.github/workflows/automerge.yml` is present. If automerge.yml exists, route to Flow A even without protection (the team uses PR-based merges by convention).

```bash
# If currently on default branch, push directly
git push origin "$DEFAULT_BRANCH"

# If on a feature branch, ask:
#   1. Fast-forward merge into default and push
#   2. Push feature branch as-is and open a PR anyway
```

For option 1 only (user confirmed):

```bash
git checkout "$DEFAULT_BRANCH"
git pull --ff-only origin "$DEFAULT_BRANCH"
git merge --ff-only <feature_branch>   # ff-only; abort on divergence
git push origin "$DEFAULT_BRANCH"
git branch -d <feature_branch>
```

Never use `--no-ff` / merge commits unless the user asked for them.

For option 2 (PR anyway): follow Phase 2A.1 → 2A.2 (push feature branch, create PR). Since automerge.yml is absent in this flow, fall back to Flow B's `gh pr merge "$PR" --auto --squash --delete-branch` to queue the merge once checks pass — never apply an `automerge` label that no workflow consumes.

---

## Phase 5 — Post-merge cleanup

Run after Flow A/B when the user confirms the PR is merged (or `gh pr view` shows `MERGED`). Idempotent.

```bash
# 1. Update local default branch
git checkout "$DEFAULT_BRANCH"
git pull --ff-only origin "$DEFAULT_BRANCH"

# 2. Delete local feature branches whose PRs are merged
# Use `gh pr list --state merged --head <branch>` to verify before deleting.
for b in $(git branch --format='%(refname:short)' | grep -v "^$DEFAULT_BRANCH$"); do
  merged_pr=$(gh pr list --state merged --head "$b" --json number -q '.[0].number')
  if [ -n "$merged_pr" ]; then
    echo "Branch $b was merged via PR #$merged_pr — delete? (ask user)"
    # On confirmation:
    git branch -D "$b"   # -D because squash merges don't show as merged to git
  fi
done

# 3. Prune remote-tracking refs that no longer exist
git fetch --prune origin

# 4. Optional: offer to delete stale remote branches whose PRs are MERGED
gh pr list --state merged --limit 30 --json headRefName,number
# Show to user, ask per-branch. Never delete remote branches without confirmation.
```

**Never** delete a remote branch whose PR is `CLOSED` (not merged) without confirming the diff is already present in the default branch. That work could still be intentional.

---

## Output Format

After success, report concisely:

```
✅ Push2gh completed

  📁 Repo       : <owner>/<repo>
  🌿 Branch     : <feature> → <default>
  📝 Commits    : N new (<hash> …)
  🔗 PR         : #<num> <state> — <url>
  🏷️  Labels    : automerge [added|skipped: <reason>]
  🧹 Cleanup    : local/remote deletions summarized
```

Show only the lines that apply; omit irrelevant ones.

---

## Options

### Dry-run

User says "check only" / "don't push" / "preview":

```bash
git status --short
git diff --stat HEAD
gh pr list --head "$(git branch --show-current)" --state all
```

Report state, do not commit or push.

### Force push (rare)

If the user explicitly asks to rewrite a remote branch (e.g., after `git rebase`), use `--force-with-lease`, never `--force`. Warn before acting and confirm the target branch is not the default branch.

```bash
git push --force-with-lease origin <feature_branch>
```

---

## Error Handling

| Situation | Response |
|---|---|
| Auth 401/403 | Guide `gh auth login` or SSH key setup. |
| `! [rejected]` (non-ff) | Suggest `git pull --rebase origin <branch>`. Never force without consent. |
| `protected branch` on direct push | Re-route through PR flow (Flow A/B). |
| No changes, no PR, nothing to do | State that explicitly and stop. |
| Conflict markers (`<<<<<<<`) in tracked files | Abort before commit; list files. |
| CI failing on open PR | Do not add `automerge`. Surface failing check names and URLs. |
| `needs-human-review` label present | Skip automerge step entirely. |
| Pre-commit hook fails | Fix root cause, re-stage, new commit. No `--no-verify`, no `--amend`. |

---

## Decision log the skill should produce

On every invocation, the skill's internal reasoning should name:

1. The detected default branch.
2. Whether protection is on.
3. Which flow (A/B/C) was selected and why.
4. Whether there were commits to make, a PR to open, a label to apply, or cleanup to do.

Surfacing these in the final summary helps the user spot mis-detections early.
