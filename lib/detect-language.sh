# lib/detect-language.sh — choose one language overlay for a target directory.
# Usage (sourced): detect_language [<override>]
# Prints rails|python|go to stdout, hints to stderr.

_BASE_FILES_LANGS=(rails python go)

_is_valid_lang() {
  local candidate="$1"
  for l in "${_BASE_FILES_LANGS[@]}"; do
    [[ "$l" == "$candidate" ]] && return 0
  done
  return 1
}

detect_language() {
  local override="${1:-}"

  if [[ -n "$override" ]]; then
    if _is_valid_lang "$override"; then
      printf '%s\n' "$override"
      return 0
    fi
    log_error "unknown --lang value: '$override' (allowed: ${_BASE_FILES_LANGS[*]})"
    return 2
  fi

  # Manifest sniffing in the current working directory.
  if [[ -f Gemfile ]] || compgen -G "*.gemspec" >/dev/null 2>&1; then
    printf 'rails\n'; return 0
  fi
  if [[ -f pyproject.toml || -f requirements.txt || -f Pipfile ]]; then
    printf 'python\n'; return 0
  fi
  if [[ -f go.mod ]]; then
    printf 'go\n'; return 0
  fi

  # Ambiguous: interactive prompt unless suppressed.
  if [[ "${BASE_FILES_NONINTERACTIVE:-0}" == "1" ]]; then
    log_error "no manifest detected and BASE_FILES_NONINTERACTIVE=1; re-run with --lang <rails|python|go>"
    return 3
  fi

  log_warn "no language manifest detected in $(pwd)"
  printf 'Select language: ' >&2
  local choice
  select choice in "${_BASE_FILES_LANGS[@]}"; do
    if [[ -n "${choice:-}" ]]; then
      printf '%s\n' "$choice"
      return 0
    fi
  done < /dev/tty
  log_error "no selection made"
  return 3
}
