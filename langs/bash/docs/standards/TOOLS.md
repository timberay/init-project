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
