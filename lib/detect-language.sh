# lib/detect-language.sh — choose one language overlay for a target directory.
# Usage (sourced): detect_language [<override>]
# Prints rails|python|go|bash|nextjs to stdout, hints to stderr.

_BASE_FILES_LANGS=(rails python go bash nextjs)

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
  if [[ -f package.json ]]; then
    if grep -Eq '"next"[[:space:]]*:' package.json; then
      printf 'nextjs\n'; return 0
    fi
  fi
  if compgen -G "next.config.*" >/dev/null 2>&1; then
    printf 'nextjs\n'; return 0
  fi

  log_warn "no language manifest detected in $(pwd); defaulting to bash overlay"
  printf 'bash\n'
  return 0
}
