# Python Stack

> Installed by `install.sh` when a `pyproject.toml`, `requirements.txt`, or
> `Pipfile` was detected. To switch language overlay, re-run
> `install.sh --lang <other>`.

## Project Layout

```
.
├── pyproject.toml          # project metadata, dependencies, tool config
├── src/
│   └── <package>/__init__.py
├── tests/
│   └── conftest.py
└── README.md
```

Use the `src/` layout (not a flat top-level package). It prevents accidental
imports of in-tree modules during testing and surfaces missing-dependency
bugs before they reach production.

## Dependency Management

**Default: `uv`.** Reasons: lockfile-by-default, single tool for install +
run + venv, fast cold install.

```bash
uv init                  # one-time project init
uv add fastapi           # add a runtime dep
uv add --dev pytest ruff # add dev deps
uv sync                  # install from lock
uv run pytest            # run inside the venv without activation
```

Alternatives: `poetry` (acceptable when team standard), `pip-tools` (acceptable
for legacy projects). Avoid bare `pip install` without a lockfile.

Pin the Python version in `.python-version` (pyenv-compatible) or in
`pyproject.toml`'s `requires-python`.

## Framework Choice

| Workload                     | Recommended                        |
|------------------------------|------------------------------------|
| HTTP API, async-first        | FastAPI                            |
| HTTP API, sync-first         | Flask + Flask-Smorest, or Litestar |
| Full-stack with admin / ORM  | Django                             |
| CLI                          | Typer                              |
| Data pipeline / scheduling   | Prefect or Dagster                 |

For Django, use Django 5.x (LTS where available). For FastAPI, pin SQLAlchemy
2.x and use the new typed `Mapped` style. For async DB access, use
`asyncpg` or `databases`, not the sync DB-API in an async handler.

## Database & Migrations

- **ORM**: SQLAlchemy 2.x (preferred) or Django ORM. Avoid raw psycopg in app
  code; reserve raw SQL for migrations and ad-hoc scripts.
- **Migrations**: `alembic` (SQLAlchemy) or `django migrate` (Django). Never
  hand-edit a migration after it has been applied in any environment.
- **Connection pooling**: `asyncpg` has built-in pooling; SQLAlchemy uses
  `QueuePool` by default. Tune pool size to match worker concurrency.

## Background Jobs

| Need                          | Choice                                |
|-------------------------------|---------------------------------------|
| Simple async queue            | `arq` (Redis)                         |
| Mature task queue              | `dramatiq` (Redis or RabbitMQ)        |
| Legacy / Django integration   | `celery` + Redis                      |

Move slow third-party work (LLM, scraping, PDF generation) off the request
path. The user sees a polled or streamed status, never a blocked request.

## Caching

- **Process-local**: `functools.lru_cache` for pure functions
- **Cross-process**: Redis via `redis-py` async client
- Cache only what is both hot and slow (>50 ms recompute, data stable for at
  least one request). Always include a versioning key so stale entries clear
  on deploy.

## Security Specifics

- **CSRF**: Django ships CSRF middleware enabled by default; never disable it.
  FastAPI does not — wire `csrf-protect` middleware for non-API HTML routes.
- **Input validation**: Pydantic v2 for FastAPI request models; Django Forms
  for Django routes. Never trust `request.body` without parsing.
- **SQL injection**: always use the ORM or DB-API parameter placeholders
  (`%s`, never `f"... {value} ..."` in queries).
- **XSS**: Jinja2 and Django templates auto-escape by default — keep them on.
- **Secrets**: `pydantic-settings` reads from env / `.env` (gitignored) for
  local dev; production secrets come from the platform's secrets manager.
- **Rate limiting**: `slowapi` (FastAPI) or `django-ratelimit` for auth and
  public endpoints.

## Logging & Observability

- `structlog` for structured logs (JSON in production, human in dev)
- OpenTelemetry SDK for traces; export to whatever backend the platform
  provides
- Always log request_id / correlation_id; propagate across background-job
  boundaries

## Deployment

Containerize with a minimal Python base image (`python:3.12-slim` or
`gcr.io/distroless/python3`). Run with `uvicorn` (ASGI) or `gunicorn +
uvicorn workers`. Health endpoints (`/healthz`) return process status, not
DB status; readiness endpoints (`/readyz`) include DB / Redis reachability.

## Internationalization

- `babel` + gettext (`.po` files) for Django; `python-i18n` or
  `fluent.runtime` for FastAPI
- Source strings in English; translation files per locale under `locale/`
