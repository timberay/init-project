# Shell Stack

Use this overlay for shell-first repositories, automation scripts, dotfile
tools, bootstrap templates, and otherwise empty repositories that do not yet
declare a framework-specific manifest.

## Runtime

- Bash is the default shell target.
- Prefer POSIX-compatible shell only when portability is an explicit project
  requirement.
- Keep scripts small and composable; move complex parsing to a stronger
  language once shell stops being the simplest tool.

## Script Conventions

- Start executable scripts with `#!/usr/bin/env bash`.
- Use `set -euo pipefail` for non-interactive scripts unless a script has a
  specific reason to handle failures manually.
- Quote variable expansions unless word splitting is intentional.
- Prefer arrays over string-built command lines.
- Resolve paths relative to the script directory when scripts read project
  files.

