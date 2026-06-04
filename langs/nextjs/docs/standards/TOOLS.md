# Next.js Toolchain

> Installed by `install.sh` when Next.js was detected. The hooks in
> `.claude/settings.json`, `.pre-commit-config.yaml`, and CI should stay in
> sync with this document.

## Required

| Tool | Purpose | Install hint |
|------|---------|--------------|
| `node` | Runtime, 22 LTS recommended | `brew install node` or use `nvm`/`fnm`/`asdf` |
| `npm` | Package manager when `package-lock.json` exists | Ships with Node.js |
| `pre-commit` | Git-side hook framework | `pipx install pre-commit` or `uv tool install pre-commit` |

## Recommended

| Tool | Purpose |
|------|---------|
| `eslint` | Linting |
| `prettier` | Formatting |
| `typescript` | Static type checking |
| `vitest` or `jest` | Unit/component tests |
| `playwright` | Browser flow tests |

## Commands

### Install

```bash
npm ci                         # when package-lock.json exists
npm install                    # when no lockfile exists yet
```

### Linting and Formatting

```bash
npm run lint                   # project lint script
npx prettier --write .         # format when prettier is installed
```

The `PostToolUse` hook formats and lints edited JS/TS files only when local
`prettier` or `eslint` binaries are installed. Missing tools are treated as a
no-op so a fresh install is not blocked.

### Type Checking

```bash
npm run typecheck              # recommended script: tsc --noEmit
```

Add this script to `package.json`:

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit"
  }
}
```

### Tests and Build

```bash
npm test                       # unit/component tests
npm run build                  # production build
npx playwright test            # browser tests, when configured
```

CI runs `pre-commit run --all-files`, `npm test --if-present`, and
`npm run build --if-present`.

## Pre-commit Gate

The Next.js overlay runs:

1. Common hygiene hooks from `pre-commit/pre-commit-hooks`
2. `npm run lint --if-present`
3. `npm run typecheck --if-present`

Keep these commands fast enough for commit-time feedback. Put slow browser
tests in CI unless a specific workflow needs local enforcement.
