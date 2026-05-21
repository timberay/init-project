# Python Toolchain

> Installed by `install.sh` when Python was detected. The pre-commit hooks in
> `.claude/settings.json` invoke these commands; keep them in sync with this
> document.

## Required

| Tool      | Purpose                                    | Install hint                                  |
|-----------|--------------------------------------------|-----------------------------------------------|
| `python`  | Runtime (≥ 3.11 recommended)               | `pyenv install 3.12` or system package        |
| `uv`      | Dependency manager + venv runner           | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `ruff`    | Linter + formatter                         | `uv add --dev ruff` (or `pipx install ruff`)  |
| `pytest`  | Test runner                                | `uv add --dev pytest`                         |

## Recommended

| Tool          | Purpose                                  |
|---------------|------------------------------------------|
| `mypy`        | Static type checking                     |
| `pip-audit`   | Dependency vulnerability scan            |
| `bandit`      | Static security scan                     |
| `pre-commit`  | Git-side hook framework (optional)       |

## Commands

### Tests

```bash
uv run pytest -q                     # full suite
uv run pytest -q tests/test_x.py     # one file
uv run pytest -q -k "test_name"      # by name
uv run pytest --lf                   # rerun last failures
```

The pre-commit hook runs `pytest -q` and denies the commit on non-zero exit.

### Linting & formatting

```bash
uv run ruff format .                 # apply formatting
uv run ruff check .                  # lint
uv run ruff check --fix .            # auto-fix safe issues
```

The pre-commit hook runs `ruff check .`; the `PostToolUse` hook on
`Write|Edit` runs `ruff format <file>` then `ruff check <file>` on the file
that was just modified.

### Type checking

```bash
uv run mypy src                       # strict mode is recommended
```

Add to CI; not in the pre-commit hook by default (too slow on large
codebases).

### Security

```bash
uv run pip-audit                      # dependency CVEs
uv run bandit -r src                  # source scan
```

### Database migrations

```bash
uv run alembic revision --autogenerate -m "<message>"
uv run alembic upgrade head
uv run alembic downgrade -1           # only in dev
```

(Replace with `manage.py migrate` for Django.)

### Running the app

```bash
uv run uvicorn app.main:app --reload  # FastAPI in dev
uv run python manage.py runserver     # Django in dev
```

## Pre-commit gate (enforced by `.claude/settings.json`)

1. `pytest -q` — timeout 120s
2. `ruff check .` — timeout 60s

Either failure denies the commit with the captured output. Fix locally and
retry. Never use `git commit --no-verify`.
