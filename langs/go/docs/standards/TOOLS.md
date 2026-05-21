# Go Toolchain

> Installed by `install.sh` when Go was detected. The pre-commit hooks in
> `.claude/settings.json` invoke these commands; keep them in sync with this
> document.

## Required

| Tool             | Purpose                                | Install hint                                                |
|------------------|----------------------------------------|-------------------------------------------------------------|
| `go`             | Runtime + build tool (≥ 1.22)          | `brew install go` or system package                          |
| `gofmt`          | Formatter (ships with `go`)            | bundled                                                      |
| `go vet`         | Built-in static analysis               | bundled                                                      |
| `golangci-lint`  | Aggregate linter                       | `brew install golangci-lint` or `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` |

## Recommended

| Tool             | Purpose                            |
|------------------|------------------------------------|
| `staticcheck`    | Deeper SA (subset of golangci-lint) |
| `govulncheck`    | Vulnerability scan                  |
| `delve`          | Debugger                            |
| `air`            | Live reload during dev              |

## Commands

### Tests

```bash
go test ./...                      # full suite
go test ./pkg/foo -run TestBar     # one test
go test -race ./...                # race detector (run in CI)
go test -cover ./...               # coverage summary
```

The pre-commit hook runs `go test ./...` and denies the commit on non-zero
exit.

### Formatting

```bash
gofmt -w .                          # apply formatting in place
goimports -w .                      # gofmt + manage imports (if installed)
```

`PostToolUse` runs `gofmt -w <file>` on the file that was just edited.

### Linting

```bash
go vet ./...                        # built-in
golangci-lint run                   # aggregate
golangci-lint run --fix             # auto-fix where supported
```

The pre-commit hook runs `golangci-lint run`.

### Security

```bash
govulncheck ./...                   # known CVEs in dependencies + stdlib
```

### Build

```bash
go build -trimpath -ldflags "-s -w" -o ./bin/<app> ./cmd/<app>
```

### Database migrations

```bash
migrate -path ./migrations -database "$DATABASE_URL" up
migrate -path ./migrations -database "$DATABASE_URL" down 1
```

(Replace with `goose -dir ./migrations <db> up` if using `pressly/goose`.)

### Running the app (dev)

```bash
go run ./cmd/<app>
air                                 # if Air is installed for live reload
```

## Pre-commit gate (enforced by `.claude/settings.json`)

1. `go test ./...` — timeout 180s
2. `golangci-lint run` — timeout 90s

Either failure denies the commit with the captured output. Fix locally and
retry. Never use `git commit --no-verify`.
