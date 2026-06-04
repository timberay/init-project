# lib/check-deps.sh — verify presence of required CLI tools.
# Usage (sourced): check_deps <language>
# Populates the array MISSING_DEPS with missing tool names; never exits.

# Override-able lists. Defaults are sensible; tests can override before calling.
: "${REQUIRED_OS:=}"
if [[ -z "${REQUIRED_OS:-}" ]]; then
  REQUIRED_OS=(jq git pre-commit)
fi

: "${REQUIRED_LANG_rails:=}"; [[ -z "${REQUIRED_LANG_rails:-}" ]] && REQUIRED_LANG_rails=(ruby)
: "${REQUIRED_LANG_python:=}"; [[ -z "${REQUIRED_LANG_python:-}" ]] && REQUIRED_LANG_python=(python3)
: "${REQUIRED_LANG_go:=}"; [[ -z "${REQUIRED_LANG_go:-}" ]] && REQUIRED_LANG_go=(go)
: "${REQUIRED_LANG_bash:=}"; [[ -z "${REQUIRED_LANG_bash:-}" ]] && REQUIRED_LANG_bash=(bash)
: "${REQUIRED_LANG_nextjs:=}"; [[ -z "${REQUIRED_LANG_nextjs:-}" ]] && REQUIRED_LANG_nextjs=(node npm)

_install_hint() {
  case "$1" in
    jq)      echo "sudo apt install -y jq        # or: brew install jq" ;;
    git)     echo "sudo apt install -y git       # or: brew install git" ;;
    gh)      echo "sudo apt install -y gh        # or: brew install gh" ;;
    ruby)    echo "brew install rbenv && rbenv install 3.3.0  # or use system package" ;;
    python3) echo "brew install pyenv && pyenv install 3.12   # or use system package" ;;
    go)      echo "brew install go               # or use system package" ;;
    bash)    echo "brew install bash             # or use system package" ;;
    node)    echo "brew install node             # or use nvm/fnm/asdf" ;;
    npm)     echo "ships with Node.js            # or reinstall Node.js" ;;
    shellcheck) echo "brew install shellcheck       # or: sudo apt install -y shellcheck" ;;
    shfmt)   echo "brew install shfmt            # or: go install mvdan.cc/sh/v3/cmd/shfmt@latest" ;;
    claude)     echo "see https://docs.claude.com/claude-code for the install script" ;;
    pre-commit) echo "pipx install pre-commit          # or: uv tool install pre-commit" ;;
    *)       echo "install '$1' via your package manager" ;;
  esac
}

check_deps() {
  local lang="${1:-}"
  MISSING_DEPS=()

  local all=()
  for t in "${REQUIRED_OS[@]}"; do all+=("$t"); done
  case "$lang" in
    rails)  for t in "${REQUIRED_LANG_rails[@]}";  do all+=("$t"); done ;;
    python) for t in "${REQUIRED_LANG_python[@]}"; do all+=("$t"); done ;;
    go)     for t in "${REQUIRED_LANG_go[@]}";     do all+=("$t"); done ;;
    bash)   for t in "${REQUIRED_LANG_bash[@]}";   do all+=("$t"); done ;;
    nextjs) for t in "${REQUIRED_LANG_nextjs[@]}"; do all+=("$t"); done ;;
  esac

  for t in "${all[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      log_ok "$t found"
    else
      MISSING_DEPS+=("$t")
      log_warn "$t missing — install with: $(_install_hint "$t")"
    fi
  done

  return 0
}
