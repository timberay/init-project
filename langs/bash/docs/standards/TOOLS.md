# Shell Tools

## Format

```bash
shfmt -w .
```

## Lint

```bash
shellcheck **/*.sh
```

## Syntax Check

```bash
find . -name '*.sh' -print0 | xargs -0 -r bash -n
```

## Verify

```bash
pre-commit run --all-files
```

## Test Container Teardown

Register teardown with `trap` so containers are removed even when a test fails
under `set -euo pipefail`. Use the same engine for setup and teardown
(`docker` or `podman`).

```bash
cid="$(docker run -d --rm myimage)"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
```

For Compose-managed stacks, tear down the whole project including volumes:

```bash
trap 'docker compose down -v --remove-orphans' EXIT
```

- Append to an existing trap rather than overwriting it when a script already
  sets an `EXIT` handler.
- Keep teardown idempotent (`|| true`) so cleanup never masks the test's own
  exit status.
- Prune leftovers from interrupted runs before starting:
  `docker ps -aq -f label=project=mytests | xargs -r docker rm -f`.
